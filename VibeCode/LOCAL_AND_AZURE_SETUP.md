# Local and Azure Setup

This guide covers running the Intune Helpdesk app locally and deploying it to Azure Static Web Apps (SWA). Adjust commands if the project’s package scripts or folder layout differ.

## Prerequisites

- Node.js LTS and npm
- An Azure subscription
- An Entra ID tenant with permission to register applications
- Intune access and the appropriate Intune RBAC role for the tasks you perform

## Run locally

1. Register an application in **Microsoft Entra ID**.
2. Under **Authentication**, add a **Single-page application (SPA)** redirect URI:
   `http://localhost:5173/`
3. Add the Microsoft Graph **delegated permission** `DeviceManagementManagedDevices.Read.All` for the implemented read-only dashboard, search, device details, and compliance status.
   For the device detail actions, also add:
   - `DeviceManagementManagedDevices.PrivilegedOperations.All` for **Sync device** and **Wipe device**.
   - `BitlockerKey.Read.All` for **Get BitLocker recovery keys** and **Reveal recovery key**.
   Grant administrator consent. These additional scopes are requested on demand when
   an operator uses the respective action, not at initial sign-in. Allow authentication
   popups when prompted. Reading recovery passwords also requires device ownership or
   an appropriate Microsoft Entra role (for example Helpdesk Administrator with the
   applicable BitLocker recovery permission); Graph consent alone is insufficient.
   Startup PIN retrieval and restart are not implemented.
4. Have an administrator grant consent where required. Graph permissions alone do not replace Intune RBAC or other tenant policies.
5. Create `intune-helpdesk\.env.local` using the variable names expected by the app's MSAL configuration:

   ```dotenv
   VITE_ENTRA_CLIENT_ID=your-application-client-id
   VITE_ENTRA_TENANT_ID=your-tenant-id
   ```

   Vite variables are included in the browser bundle. Never put a client secret, certificate, access token, or other credential in a `VITE_` variable or commit a local environment file.

6. Install dependencies and start the app:

   ```powershell
   cd intune-helpdesk
   npm install
   npm run dev
   ```

   Open `http://localhost:5173/`. Without `.env.local`, the app shows the setup screen.
   After adding the Entra values, restart Vite and select **Sign in with Microsoft**.
   Allow the sign-in popup if your browser blocks it. The frontend acquires a delegated
   token and reads Intune managed devices directly from Microsoft Graph. No local
   Functions API or SWA CLI is needed. The existing `api` folder is an unfinished scaffold
   and is not used by this workflow. The Vite port is strict to avoid redirect URI mismatches.

7. Run the available checks:

   ```powershell
   npm run build
   npm test
   ```

   Run only scripts that are defined in `package.json`.

## Deploy to Azure Static Web Apps

### PowerShell deployment (no GitHub connection required)

The script deploys only the frontend, including the direct Graph device actions. It creates a resource group
and Static Web App if they do not exist, or deploys to the named existing app.
It defaults to the Free SKU; existing resource SKUs and locations are not changed.
Review the subscription and app name carefully: an existing app's production content
will be replaced. Azure policies, quotas, or selected paid SKUs may affect cost.

Install Node.js LTS, Azure CLI, and the SWA CLI, then authenticate:

```powershell
npm install --global @azure/static-web-apps-cli
az login
cd D:\source\MMSMidwayTools\intune-helpdesk

# Preview the intended target without building or changing Azure.
.\Deploy-Azure.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -ResourceGroupName 'rg-intune-helpdesk' `
  -AppName 'intune-helpdesk-demo' `
  -WhatIf

# Build, test, create/reuse resources, and publish production content.
.\Deploy-Azure.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -ResourceGroupName 'rg-intune-helpdesk' `
  -AppName 'intune-helpdesk-demo' `
  -Location 'eastus2'
```

The signed-in Azure account needs resource creation/deployment permissions and
permission to list the app's deployment token. `npm ci` restores the lockfile's
dependencies; the script then type-checks, tests, and builds before creating resources.
It uses Vite production-mode settings, including `.env.local`. To override IDs
explicitly, pass `-EntraClientId '<client-guid>' -EntraTenantId '<tenant-guid>'`.
No local environment file is uploaded; the client and tenant IDs are public values
embedded in the browser bundle. The deployment token is passed through a temporary
process environment variable, not printed or saved, and the original environment
is restored on success or failure.

The script prints the HTTPS app URL. **Add that exact URL, including the trailing
slash, as an SPA redirect URI in your Entra app registration before signing in.**
It does not update Entra registration or grant administrator consent. It deliberately
uses the browser origin for redirects, ignoring any local redirect override during
the build. Sign-in and Intune access must be verified in the deployed browser session.

Hosting configuration lives in `intune-helpdesk\public\staticwebapp.config.json`,
so Vite copies it into `dist`. It supports SPA deep links without configuring a
second, unused SWA server-side login provider.

### Optional GitHub deployment

1. Create an SWA resource in Azure and connect it to the repository’s deployment branch.
2. Configure the build for the repository layout. For a Vite app at the repository root, typical values are:
   - App location: `intune-helpdesk` (or `/` if deploying from the app folder)
   - API location: leave blank for the direct Graph workflow
   - Output location: `dist`
   - Build command: `npm run build`
3. Set the Entra application’s SPA redirect URI to the deployed app’s HTTPS origin, for example:
   `https://<your-app-name>.azurestaticapps.net/`
   Add the production URI and any custom-domain URI to the app registration. Keep the local redirect URI for development.
4. Configure the Vite client ID and tenant ID as **GitHub Actions variables** used during the build, or as build-environment variables in the deployment workflow. These values are public configuration, not secrets. Do not add a client secret to the frontend build.
5. Confirm the deployed app uses HTTPS, the correct redirect URI, and the intended tenant. Test sign-in and each feature with an authorized account.
6. If using a custom domain, add it to SWA and add its origin as a redirect URI in the Entra app registration.

## Running the frontend and API locally

**For the current app, run only `npm run dev` from `intune-helpdesk`.**
Dashboard, search, and details use Microsoft Graph directly after MSAL sign-in.
There is no API process to start for these features.

The `api` folder cannot currently serve usable endpoints: it has no function
registrations or TypeScript compilation pipeline, targets obsolete Node 14, imports
missing service exports, and uses a placeholder access token. `npm start` there only
invokes `func start`; installing Functions Core Tools alone will not fix it.
Do not replace the placeholder with a hardcoded token or a frontend client secret.

After a separate backend implementation is completed, the usual SWA local workflow
would be two terminals:

```powershell
# Terminal 1: frontend
cd D:\source\MMSMidwayTools\intune-helpdesk
npm run dev

# Terminal 2: SWA proxy plus a properly implemented Functions API
cd D:\source\MMSMidwayTools\intune-helpdesk
swa start http://localhost:5173 --api-location .\api
```

That is a **future workflow, not a working command for the current API scaffold**.
It requires a supported Functions runtime, registered HTTP functions, a working build,
and delegated-token validation/authorization. The browser would use the SWA proxy
origin (normally `http://localhost:4280/`), which must also be registered as an Entra
SPA redirect URI. The frontend would need to be explicitly wired to `/api` for
features handled by that backend.

## Security and operations

- Keep Graph access delegated to the signed-in user and request the minimum permissions the app needs. Verify permission names and consent requirements against current Microsoft Graph documentation before deployment.
- Require explicit confirmation for destructive actions such as wipe. Enforce authorization through Entra permissions and Intune RBAC; hiding a UI action is not authorization.
- Do not log access tokens, BitLocker recovery keys, or other sensitive values. Log action metadata and errors without secrets, and restrict access to audit records.
- Review Entra sign-in logs, SWA deployment logs, and application errors when troubleshooting.

## Troubleshooting

- **Redirect URI mismatch:** The redirect URI configured in MSAL must exactly match an SPA redirect URI in the app registration, including scheme and path.
- **Consent or authorization error:** Check Graph delegated permissions, administrator consent, user sign-in, tenant policies, and Intune RBAC.
- **Graph HTTP 403:** Grant administrator consent for delegated `DeviceManagementManagedDevices.Read.All` and check the tenant's Intune license and the user's Intune RBAC access.
- **Graph HTTP 401 or expired consent/session:** Sign out and sign in again.
- **Old "Check that the local API is running" message:** Restart Vite and refresh the page. The app uses Microsoft Graph directly, not `/api/devices`.
- **Production uses stale configuration:** Vite values are embedded at build time. Update the deployment build variables and redeploy.

## Device actions

**Wipe device** is available on Windows device details only. It opens a destructive
confirmation dialog showing the device name and Intune ID. Type the exact device
name (or Intune ID for unnamed devices) and select **Permanently wipe device**.
The request explicitly sets `keepEnrollmentData` and `keepUserData` to `false`:
this is a factory reset request, not retirement or an enrollment-preserving reset.
Back up required data first. Mac/mobile wipe options are not implemented here.
The operator needs the delegated privileged-operations permission above with admin
consent and Intune RBAC permission to wipe the target device.

A successful response means **requested**, not completed. The app does not automatically
retry wipe requests and disables further wipe submissions after success until the
details component is reloaded. If a network failure leaves the outcome unclear,
check Intune action status before issuing another command. The confirmation dialog
is a safety check, not an authorization boundary; Graph/Intune enforce authorization.

Open **View details** from the dashboard or search. **Sync device** queues an Intune
sync request; Graph's successful response does not confirm that the device has completed
its check-in. Use **Refresh details** later to see the last reported check-in time.
Do not grant extra permissions to users who only need the dashboard.

On Windows devices, **Get BitLocker recovery keys** lists escrowed key IDs using the
device's Microsoft Entra device ID, not its Intune managed device ID. Match the ID
to the recovery screen, then select **Reveal recovery key** for that specific key.
It retrieves the 48-digit recovery password, not a startup PIN. Entra audits the reveal.
No key is fetched automatically, logged, copied to the clipboard, or stored in browser
storage by this app. A revealed password hides after 60 seconds, on navigation, or
when the tab becomes hidden. Treat screenshots and screen sharing as sensitive.
If the Entra device ID is missing or no escrowed keys are returned, check device
enrollment and recovery-key backup rather than using the Intune ID as a substitute.
