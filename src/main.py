import base64
import json
import update_vpc_peering
import os


def update_peering(data: dict, context: dict) -> dict:
    data_buffer = base64.b64decode(data["data"])
    log_entry = json.loads(data_buffer['protoPayload'])
    network_name = os.environ["NETWORK_NAME"]
    project_id   = os.environ["PROJECT_ID"]
    try:
        peering_name = log_entry.request.networkPeering.name
    except Exception:
        status = {"status": False, "msg": "Failed to extract peering name from log msg..."}
        peering_name = None
    if peering_name:
        status = update_vpc_peering.update_peering(network_name=network_name, project_id=project_id, peering_name=peering_name)
    return status
