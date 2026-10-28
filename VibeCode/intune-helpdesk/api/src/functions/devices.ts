import { AzureFunction, Context, HttpRequest } from "@azure/functions";
import { getDevices, getDeviceById } from "../services/graphService";
import { Device } from "../types/index";

const devicesFunction: AzureFunction = async (context: Context, req: HttpRequest): Promise<void> => {
    const deviceId = req.query.deviceId;

    if (deviceId) {
        const device: Device | null = await getDeviceById(deviceId);
        if (device) {
            context.res = {
                status: 200,
                body: device
            };
        } else {
            context.res = {
                status: 404,
                body: { message: "Device not found" }
            };
        }
    } else {
        const devices: Device[] = await getDevices();
        context.res = {
            status: 200,
            body: devices
        };
    }
};

export default devicesFunction;