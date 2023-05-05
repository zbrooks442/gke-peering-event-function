from google.cloud import compute_v1
import copy
import time


class updateVpcPeering:
    """
    Class used to update VPC peerings
    """

    def __init__(self, network_name, peering_name, project_id):
        self.client = compute_v1.NetworksClient()
        self.network_name = network_name
        self.project_id = project_id
        self.peering_name = peering_name
        self.network = None

    def return_network(self) -> object:
        """Returns network for Google compute API which contains the VPC Peering

        Args:
            self (updateVpcPeering): Instance of the Class

        Returns:
            network (object): Returns Network Object

        Raises:
        """
        self.network = self.client.get(
            project=self.project_id, network=self.network_name
        )
        return self.network

    def return_updates(self) -> object:
        """Parses VPC Peerings and returns peering to update

        Args:
            self (updateVpcPeering): Instance of the Class

        Returns:
            update (object): Peering Object with updated attribute (export_custom_routes=True)
        
        Raises:
        """
        peerings = self.network.peerings
        update = None
        for peering in peerings:
            if peering.name.startswith("gke-") and peering.name.endswith("-peer"):
                if not peering.export_custom_routes:
                    update = copy.deepcopy(peering)
                    update.export_custom_routes = True
        return update

    def update_peering(self, update: object) -> dict:
        """Runs update_peering operation to add export_custom_routes=True to the peering

        Args:
            self (updateVpcPeering): Instance of the Class
            update (object): Peering Object with updated attribute

        Returns:
            status (dict): Status object containing bool and msg
        
        Raises:
        """
        try:
            request = compute_v1.NetworksUpdatePeeringRequest(network_peering=update)
            response = self.client.update_peering(
                project=self.project_id,
                network=self.network_name,
                networks_update_peering_request_resource=request,
            )
            success = self.check_status(response=response)
            if success:
                status = {
                    "status": success,
                    "msg": f"Successfully updated peering {self.peering_name}...",
                }
            else:
                status = {
                    "status": success,
                    "msg": f"Failed to update peering {self.peering_name}...",
                }
        except Exception:
            status = {
                "status": False,
                "msg": f"Failed to update peering {self.peering_name}...",
            }
        return status

    def check_status(self, response: object) -> bool:
        """Checks the status of the response object from peering_update operation (async)
        
        Will execute done method within the class until True is returned or max_retries is exceeded

        Args:
            self (updateVpcPeering): Instance of the Class
            response (object): Response object from peering operation

        Returns:
            status (bool): Bool indicating the operation finished
        
        Raises:
        """
        max_retries = 5
        wait = 5
        status = False
        for cnt in range(max_retries):
            status = response.done()
            if status:
                break
            time.sleep(wait)
        return status

    def run_peering_update(self) -> dict:
        """Runs peering update (entrypoint method)

        Args:
            self (updateVpcPeering): Instance of the Class

        Returns:
            status (dict): Status object containing bool and msg
        
        Raises:
        """
        self.return_network()
        update = self.return_updates()
        if update:
            status = self.update_peering(update)
        else:
            status = {
                "status": True,
                "msg": f"Peering {self.peering_name} already has export_custom_routes enabled...",
            }
        return status


def update_peering(network_name: str, peering_name: str, project_id: str) -> dict:
    """Runs peering update, wrapper function for updateVpcPeering class

    Args:
        network_name (str): Name of the VPC with the Peering
        peering_name (str): Name of the GKE Peering to update
        project_id (str): Project ID where network/peering exists

    Returns:
        status (dict): Status object containing bool and msg
    
    Raises:
    """
    status = updateVpcPeering(
        network_name=network_name, project_id=project_id, peering_name=peering_name
    ).run_peering_update()
    return status
