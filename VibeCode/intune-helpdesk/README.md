# Intune Helpdesk Application

This Intune helpdesk frontend signs users in with Microsoft Entra ID and uses delegated Microsoft Graph access for device details, sync requests, Windows device wipe, and on-demand BitLocker recovery. Restart, startup PIN retrieval, and application-managed persistent audit logging are not implemented.

## Features

- **Device Search**: Search loaded devices by name or Intune ID and view details.
- **User Authentication**: Microsoft Entra sign-in with delegated Graph access.
- **Dashboard**: Overview of device statuses, including compliance status, last check-in time, and alerts.
- **Errors**: Sign-in and Graph failures are displayed with retry and permission guidance.
- **Device actions**: Request an Intune sync or list and explicitly reveal a Windows device's escrowed BitLocker recovery password. Reveals are audited by Entra and hidden after 60 seconds or when leaving the page/tab.

## Project Structure

- **api**: Unfinished backend scaffold; not used or required by the current frontend.
  - `src/functions`: Functions for device management, actions, and audit logs.
  - `src/services`: Service for interacting with the Microsoft Graph API.
  - `src/types`: Type definitions for the API.
  - `host.json`: Configuration for Azure Functions.
  - `package.json`: Dependencies and scripts for the API.

- **src**: Contains the frontend application built with React.
  - `auth`: Configuration for Microsoft Authentication Library (MSAL).
  - `components`: React components for device search, details, and dashboard.
  - `services`: Service for reading Intune managed devices directly from Graph.
  - `types`: Type definitions for device data.
  - `App.tsx`: Main entry point for the React application.
  - `main.tsx`: Initializes the React application.

- **public**: Static assets for the application.

- **public/staticwebapp.config.json**: SPA routing configuration copied into the build output.

- **Deploy-Azure.ps1**: Builds, tests, and deploys the frontend to Azure Static Web Apps using Azure CLI and SWA CLI. See [local and Azure setup](../LOCAL_AND_AZURE_SETUP.md) for prerequisites, parameters, and the required Entra redirect URI.

- **index.html**: Main HTML file for the application.

- **package.json**: Dependencies and scripts for the frontend.

- **tsconfig.json**: TypeScript configuration.

- **vite.config.ts**: Configuration for Vite.

## Setup Instructions

1. Open the application folder:
   ```
   cd intune-helpdesk
   ```

2. Install the frontend dependencies and start the local UI:
   ```
   npm install
   npm run dev
   ```
   Vite prints the local URL (by default `http://localhost:5173/`). The setup screen appears until `VITE_ENTRA_CLIENT_ID` and `VITE_ENTRA_TENANT_ID` are provided in `.env.local`.

3. Add the SPA app's Entra IDs to `.env.local`, grant admin consent for the Graph delegated permission `DeviceManagementManagedDevices.Read.All`, and restart Vite. Add `http://localhost:5173/` as an SPA redirect URI and sign in using the on-screen button. The account needs Intune access and the tenant needs an active Intune license. No API process or client secret is needed.
   For sync and Windows device wipe, also grant `DeviceManagementManagedDevices.PrivilegedOperations.All` and ensure the operator has the required Intune RBAC permissions.
   For BitLocker recovery, grant `BitlockerKey.Read.All` and ensure the operator has
   device ownership or a supported Entra role/BitLocker recovery permission.
   Additional scopes are requested only when the corresponding action is used.

4. Validate with `npm run build`, `npx tsc --noEmit`, and `npm test -- --runInBand`.

## Usage Guidelines

- Use the search bar to quickly find devices by name or ID.
- Use **View details** to inspect a device, request **Sync device**, or get and reveal a matching BitLocker recovery key ID.
- **Wipe device** (Windows only) requires typing the exact device name in a confirmation dialog. It requests a destructive factory reset without retaining user or enrollment data; back up required data first. Success confirms a request, not completion.
- Monitor the dashboard for an overview of device statuses and alerts.

## Contributing

Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for details.