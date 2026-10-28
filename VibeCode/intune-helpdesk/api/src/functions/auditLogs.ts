import { AzureFunction, Context, HttpRequest } from "@azure/functions";
import { getAuditLogs } from "../services/graphService";

const auditLogsFunction: AzureFunction = async (context: Context, req: HttpRequest): Promise<void> => {
    context.log('Processing request for audit logs');

    try {
        const logs = await getAuditLogs();
        context.res = {
            status: 200,
            body: logs
        };
    } catch (error) {
        context.log.error('Error retrieving audit logs:', error);
        context.res = {
            status: 500,
            body: { message: 'Error retrieving audit logs' }
        };
    }
};

export default auditLogsFunction;