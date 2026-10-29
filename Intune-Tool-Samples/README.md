# Microsoft Graph Helpdesk PowerShell Toolkit

A collection of PowerShell scripts that demonstrate a small helpdesk toolkit built directly on the Microsoft Graph REST API. The examples use delegated, interactive Microsoft Entra ID authentication with PKCE and include device lookup, Windows LAPS password retrieval, BitLocker recovery key retrieval, Intune device sync, and scoped Microsoft Entra group membership management.



## Scripts

| Script | Purpose |
|---|---|
| `UserAuth.ps1` | Standalone example of interactive Microsoft Graph authentication using OAuth 2.0 authorization code flow with PKCE. |
| `FindDeviceLAPS.ps1` | Searches Microsoft Entra ID for a device and retrieves its Windows LAPS local administrator credential. |
| `FindDeviceBitLocker.ps1` | Searches Intune managed devices and retrieves BitLocker recovery key information for the selected device. |
| `Trigger Action.ps1` | Searches Intune managed devices and lets the operator trigger an Intune policy sync. |
| `GUIFrameWork.ps1` | UI-only Windows Forms framework showing the intended layout of the helpdesk application. The buttons are not wired to Microsoft Graph actions in this version. |
| `GUIWired.ps1` | Working Windows Forms helpdesk interface that combines device search, LAPS retrieval, BitLocker recovery key retrieval, Intune sync, copy-to-clipboard, and a local on-screen audit log. |
| `GroupMemberTool.ps1` | Windows Forms tool for adding users or devices to Microsoft Entra groups owned by the signed-in user, including single-object and bulk-entry workflows plus a local on-screen audit preview. |

The descriptions above are based on the supplied scripts. `GUIWired.ps1`, for example, searches the Intune `managedDevices` endpoint, resolves the corresponding Entra device, and exposes LAPS, BitLocker, and device-sync actions. `GroupMemberTool.ps1` deliberately loads groups from `/me/ownedObjects/microsoft.graph.group`, so group ownership is part of its scoping model.

## Prerequisites

- Windows with Windows PowerShell/PowerShell capable of running `System.Windows.Forms` for the GUI scripts.
- Access to a Microsoft Entra ID tenant and, for the Intune functions, Microsoft Intune.
- A Microsoft Entra app registration for interactive delegated authentication.
- Network access to Microsoft Entra ID sign-in endpoints and `https://graph.microsoft.com`.
- An account that is authorized to perform the operations you intend to expose.
- Windows LAPS must already be configured and backing credentials up to Microsoft Entra ID for LAPS retrieval to return a password.
- BitLocker recovery information must already exist in Microsoft Entra ID for the BitLocker lookup to return a recovery key.

## 1. Create/configure the Microsoft Entra app registration

Create or choose an app registration in Microsoft Entra ID and record:

- **Directory (tenant) ID**
- **Application (client) ID**

These values are placed directly into the scripts.

The scripts use an interactive authorization-code + PKCE flow and open a browser for sign-in. They dynamically start a listener on the local computer and build an `http://localhost:<port>/` redirect URI. Configure the app registration for the desktop/native public-client scenario appropriate for this authentication design. Microsoft documents loopback redirect URIs for desktop applications, and the redirect URI sent by an application must match a redirect URI allowed by the app registration.

No client secret is stored in these scripts.

## 2. Populate the Tenant ID and Client ID

Open every script that contains the configuration block and replace:

```powershell
$TenantId = "<YourTenantID>"
$ClientId = "<YourClientID>"
```

with your values, for example:

```powershell
$TenantId = "00000000-0000-0000-0000-000000000000"
$ClientId = "11111111-1111-1111-1111-111111111111"
```

Do not commit credentials, tokens, or secrets to the repository.

## 3. Microsoft Graph delegated permissions

The scripts themselves request the following scopes. Configure the app registration with the delegated Microsoft Graph permissions required for the scripts you plan to use, and grant/admin-consent them where your tenant requires it.

### Device/helpdesk scripts

`UserAuth.ps1`, `FindDeviceLAPS.ps1`, `FindDeviceBitLocker.ps1`, and `Trigger Action.ps1` request:

```text
openid
profile
offline_access
BitlockerKey.Read.All
Device.Read.All
Directory.Read.All
GroupMember.Read.All
Group.Read.All
DeviceManagementManagedDevices.ReadWrite.All
DeviceManagementManagedDevices.PrivilegedOperations.All
DeviceManagementScripts.Read.All
DeviceLocalCredential.Read.All
```

`GUIWired.ps1` requests:

```text
openid
profile
offline_access
BitlockerKey.Read.All
Device.Read.All
Directory.Read.All
DeviceManagementManagedDevices.ReadWrite.All
DeviceManagementManagedDevices.PrivilegedOperations.All
DeviceLocalCredential.Read.All
```

### Group membership tool

`GroupMemberTool.ps1` requests:

```text
openid
profile
offline_access
User.Read.All
Group.ReadWrite.All
Directory.Read.All
Device.Read.All
```

> [!NOTE]
> These are the scopes currently declared by the scripts, not a claim that every scope is the minimum permission needed for every operation. If you deploy this beyond a lab/demo, review each Graph call and reduce permissions according to least privilege.

## 4. Set group ownership for the Group Membership Tool

`GroupMemberTool.ps1` does **not** load every group in the tenant. After sign-in it calls the signed-in user's owned-objects endpoint and populates the **Owned Groups** selector with groups the user owns.

Before using this tool:

1. Identify the Microsoft Entra groups that a helpdesk/operator account should manage with the tool.
2. Add that operator as an **Owner** of those groups in Microsoft Entra ID.
3. Start `GroupMemberTool.ps1` and sign in using that operator account.
4. Select one of the groups shown in **Owned Groups**.
5. Add a user by UPN or a device by name, or use the bulk grid.

If the expected group does not appear, verify that the currently signed-in account is actually listed as an owner of that group.

> [!CAUTION]
> Ownership in the picker is an application-level scoping choice made by this script. The Microsoft Graph delegated permissions and the signed-in user's effective authorization still determine whether an operation succeeds. Do not treat the owned-groups dropdown as a security boundary by itself.

## Running the scripts


Then launch PowerShell and run the desired script:

```powershell
.\GUIWired.ps1
```

or:

```powershell
.\GroupMemberTool.ps1
```

If your PowerShell execution policy blocks local scripts, use your organization's approved PowerShell execution-policy process. Do not bypass an enterprise policy just to run these tools.

## Recommended starting point

For the complete helpdesk-style experience, start with:

```powershell
.\GUIWired.ps1
```

Typical workflow:

1. Click **Sign In** and complete Microsoft Entra authentication in the browser.
2. Search for a managed device by device name.
3. Review the returned device information.
4. Use **LAPS Key**, **BitLocker Key**, or **Sync Now** as needed.
5. Review the audit/status area at the bottom of the window.

The LAPS and BitLocker values are displayed in the application's **Secrets / Recovery Output** box. `GUIWired.ps1` also provides a **Copy** button.

## Using the standalone examples

### LAPS lookup

```powershell
.\FindDeviceLAPS.ps1
```

After authentication, enter a computer name. The script searches Microsoft Entra device objects and then requests the device's local credential information.

### BitLocker recovery key lookup

```powershell
.\FindDeviceBitLocker.ps1
```

Enter a computer name. The script searches Intune managed devices and, when an Entra/Azure AD device ID is present, requests associated BitLocker recovery-key objects and the recovery-key value.

### Trigger an Intune device sync

```powershell
.\TriggerAction.ps1
```

Enter a computer name and confirm the device for which you want to trigger the `syncDevice` action.

### Authentication test

```powershell
.\UserAuth.ps1
```

This is useful for validating the Tenant ID, Client ID, authentication flow, requested scopes, and basic `/me` Graph connectivity independently of the GUI.

## Group Membership Tool

```powershell
.\GroupMemberTool.ps1
```

The tool supports:

- An **Owned Groups** picker scoped to groups owned by the signed-in user.
- Adding an individual **user** by UPN.
- Searching for and adding a **device**.
- An editable bulk grid for user/device additions.
- An on-screen audit preview that records a timestamp, signed-in helpdesk UPN, target, group, and result.

### Important bulk-mode note

The current `Load Sample CSV` button does not open a CSV file from disk. It creates an in-memory sample table containing example rows, including an intentionally invalid row. Treat this as demonstration/sample functionality unless you extend the script with a file picker and `Import-Csv` logic.

## Security considerations

These scripts expose privileged helpdesk operations and potentially sensitive recovery information.

- **LAPS passwords and BitLocker recovery keys are secrets.** Do not paste them into tickets, logs, source control, or other unsecured locations.
- Apply least privilege to both the app registration and the signed-in operators.
- Use Microsoft Entra/Intune role and access controls appropriate to your organization.
- Review and approve the delegated permissions before production use.
- The GUI's audit tables are local, in-memory UI records. The supplied code does not persist those audit rows to a central logging system.
- `GUIWired.ps1` places recovered secrets in a selectable text box and can copy them to the Windows clipboard. Treat clipboard contents as sensitive.
- The device search in `GUIWired.ps1` uses the first matching managed device. In an environment where partial device names can return more than one result, validate the returned device before using a privileged quick action.
- `GroupMemberTool.ps1` can change Microsoft Entra group membership. Test with non-production groups before broader deployment.

## Troubleshooting

### Sign-in opens, but authentication fails

Check the Tenant ID and Client ID, app registration authentication configuration, redirect-URI/public-client configuration, requested delegated permissions, and tenant consent requirements.

### `AADSTS50011` / redirect URI mismatch

The redirect URI sent during authentication must be permitted by the app registration. Review the app's **Authentication** configuration and Microsoft's redirect-URI guidance.

### LAPS returns no credentials or access denied

Verify that Windows LAPS is configured to back up the account/password to Microsoft Entra ID, that the target device has a backed-up credential, and that the signed-in identity has the required Graph permission and appropriate authorization/RBAC.

### BitLocker key is not returned

Verify that a recovery key exists for the device in Microsoft Entra ID and that the signed-in identity is authorized to read BitLocker recovery keys.

### Group is missing from the Group Membership Tool

The group picker is intentionally built from groups returned as owned objects for the signed-in account. Assign the user as an owner of the intended group, sign in with that account, and launch/reconnect the tool again.

### Device search returns the wrong device

The GUI currently uses the first Intune managed-device match. Use a sufficiently specific device name and verify the device name, serial number, managed ID, and Entra/Azure AD ID displayed by the tool before retrieving a secret or sending a sync action.



## Disclaimer

These scripts are provided as examples and should be reviewed and tested in a non-production environment before use. Validate permissions, role assignments, error handling, auditing, and security requirements against your organization's standards before deploying them to helpdesk operators.
