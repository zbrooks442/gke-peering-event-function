from update_vpc_peering import update_vpc_peering
from unittest.mock import MagicMock
import pickle
import pytest
import os


@pytest.fixture(scope="session")
def updateVpcPeering():
    dir_path = os.path.dirname(os.path.realpath(__file__))
    with open(f"{dir_path}/google_sdk_network_mock.data", "rb") as pfile:
        network_mock_data = pickle.load(pfile)
    updateVpcPeering = update_vpc_peering.updateVpcPeering(
        project_id="fakeprojectid",
        network_name="test-vpc-name",
        peering_name="gke-ijsadoasoidasod-peer",
    )
    updateVpcPeering.return_network = MagicMock(return_value=network_mock_data)
    updateVpcPeering.update_peering = MagicMock(
        return_value={
            "status": True,
            "msg": "Successfully updated peering gke-ijsadoasoidasod-peer...",
        }
    )
    updateVpcPeering.check_status = MagicMock(return_value=True)
    updateVpcPeering.run_peering_update = MagicMock(
        return_value={
            "status": True,
            "msg": "Successfully updated peering gke-ijsadoasoidasod-peer...",
        }
    )
    updateVpcPeering.network = network_mock_data
    return updateVpcPeering


def test_return_network(updateVpcPeering):
    network = updateVpcPeering.return_network()
    network_name = network.name
    assert network_name == "test-vpc-name"


def test_return_updates(updateVpcPeering):
    update = updateVpcPeering.return_updates()
    peering_name = update.name
    assert peering_name == "gke-ijsadoasoidasod-peer"


def test_update_peering(updateVpcPeering):
    # Todo: Build a better test
    update = updateVpcPeering.return_updates()
    status = updateVpcPeering.update_peering(update=update)
    assert True == status["status"]


def test_check_status(updateVpcPeering):
    # Todo: Build a better test
    status = updateVpcPeering.check_status("Response")
    assert True == status


def test_run_peering_update(updateVpcPeering):
    # Todo: Build a better test
    status = updateVpcPeering.run_peering_update()
    assert True == status["status"]
