"""Generic AWS Config custom rule evaluator for CIS OS-level compliance.

One Lambda serves every CIS benchmark (RHEL9, Windows Server 2025, and any
future OS added to the pipeline) — which benchmark it evaluates is entirely
driven by the Config rule's InputParameters, never by code branching here.
That's the loose-coupling seam: modules/config-compliance can add a new
Config rule pointed at this same function ARN with new parameters, with zero
changes to this file or to modules/image-builder-*/modules/ssm-enforcement.

Config never talks to the target instance directly. It reads compliance
state that modules/ssm-enforcement already published to the SSM Compliance
API (see hardening-content/CONTRACT.md for the result-stream contract that
produces that data).

Expected rule InputParameters (set per aws_config_config_rule in main.tf):
  ComplianceType : the SSM Custom compliance type to read, e.g. "Custom:CIS-RHEL9"
  TagKey         : instance tag key that puts an instance in scope, e.g. "CISBenchmark"
  TagValue       : instance tag value that puts an instance in scope, e.g. "RHEL9"
"""

import json
import boto3

ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")
config = boto3.client("config")


def _in_scope_instance_ids(tag_key, tag_value):
    paginator = ec2.get_paginator("describe_instances")
    ids = []
    for page in paginator.paginate(
        Filters=[
            {"Name": f"tag:{tag_key}", "Values": [tag_value]},
            {"Name": "instance-state-name", "Values": ["running"]},
        ]
    ):
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                ids.append(instance["InstanceId"])
    return ids


def _instance_compliance(instance_id, compliance_type):
    """Returns (status, annotation) for one instance based on its most recent
    SSM compliance items of the given type. NON_COMPLIANT if any control
    failed or no data has ever been published (fail closed, not open)."""
    try:
        paginator = ssm.get_paginator("list_compliance_items")
        items = []
        for page in paginator.paginate(
            ResourceIds=[instance_id],
            ResourceTypes=["ManagedInstance"],
            Filters=[{"Key": "ComplianceType", "Values": [compliance_type]}],
        ):
            items.extend(page["ComplianceItems"])
    except Exception as exc:  # noqa: BLE001 - report, don't crash the evaluation
        return "NON_COMPLIANT", f"Could not read SSM compliance data: {exc}"

    if not items:
        return "NON_COMPLIANT", "No SSM compliance data published yet for this instance"

    non_compliant = [i for i in items if i.get("Status") != "COMPLIANT"]
    if non_compliant:
        ids = ", ".join(sorted({i["Id"] for i in non_compliant}))[:250]
        return "NON_COMPLIANT", f"{len(non_compliant)} control(s) failing: {ids}"

    return "COMPLIANT", f"All {len(items)} evaluated control(s) compliant"


def handler(event, _context):
    invoking_event = json.loads(event["invokingEvent"])
    rule_parameters = json.loads(event.get("ruleParameters", "{}"))

    compliance_type = rule_parameters["ComplianceType"]
    tag_key = rule_parameters["TagKey"]
    tag_value = rule_parameters["TagValue"]

    result_token = event["resultToken"]
    evaluations = []

    for instance_id in _in_scope_instance_ids(tag_key, tag_value):
        status, annotation = _instance_compliance(instance_id, compliance_type)
        evaluations.append(
            {
                "ComplianceResourceType": "AWS::EC2::Instance",
                "ComplianceResourceId": instance_id,
                "ComplianceType": status,
                "Annotation": annotation[:256],
                "OrderingTimestamp": invoking_event["notificationCreationTime"],
            }
        )

    if not evaluations:
        return {"message": f"No in-scope instances found for {tag_key}={tag_value}"}

    # PutEvaluations caps at 100 per call.
    for i in range(0, len(evaluations), 100):
        config.put_evaluations(
            Evaluations=evaluations[i : i + 100],
            ResultToken=result_token,
        )

    return {"evaluated": len(evaluations)}
