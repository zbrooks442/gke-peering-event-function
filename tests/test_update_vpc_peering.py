from update_vpc_peering import update_vpc_peering
from unittest.mock import MagicMock
import pickle
import unittest


class TestupdateVpcPeering(unittest.TestCase):
    def setUp(self):
        with open("google_sdk_network_mock.data", "rb") as pfile:
            self.network_mock_data = pickle.load(pfile)
        self.updateVpcPeering = update_vpc_peering.updateVpcPeering(
            project_id="fakeprojectid",
            network_name="test-vpc-name",
            peering_name="gke-ijsadoasoidasod-peer",
        )
        self.updateVpcPeering.return_network = MagicMock(
            return_value=self.network_mock_data
        )
        self.updateVpcPeering.update_peering = MagicMock(
            return_value={
                "status": True,
                "msg": "Successfully updated peering gke-ijsadoasoidasod-peer...",
            }
        )
        self.updateVpcPeering.check_status = MagicMock(return_value=True)
        self.updateVpcPeering.run_peering_update = MagicMock(
            return_value={
                "status": True,
                "msg": "Successfully updated peering gke-ijsadoasoidasod-peer...",
            }
        )
        self.updateVpcPeering.network = self.network_mock_data

    def test_return_network(self):
        network = self.updateVpcPeering.return_network()
        network_name = network.name
        self.assertEqual(network_name, "test-vpc-name")

    def test_return_updates(self):
        update = self.updateVpcPeering.return_updates()
        peering_name = update.name
        self.assertEqual(peering_name, "gke-ijsadoasoidasod-peer")

    def test_update_peering(self):
        # Todo: Build a better test
        update = self.updateVpcPeering.return_updates()
        status = self.updateVpcPeering.update_peering(update=update)
        self.assertEqual(True, status["status"])

    def test_check_status(self):
        # Todo: Build a better test
        status = self.updateVpcPeering.check_status("Response")
        self.assertEqual(True, status)

    def test_run_peering_update(self):
        # Todo: Build a better test
        status = self.updateVpcPeering.run_peering_update()
        self.assertEqual(True, status["status"])
