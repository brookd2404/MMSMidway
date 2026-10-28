import React, { useState } from 'react';
import { BrowserRouter as Router, Link, Route, Switch } from 'react-router-dom';
import DeviceSearch from './components/DeviceSearch';
import DeviceDetails from './components/DeviceDetails';
import Dashboard from './components/Dashboard';
import { MsalProvider, useIsAuthenticated, useMsal } from '@azure/msal-react';
import { InteractionStatus } from '@azure/msal-browser';
import { Alert, Box, Button, Container, Stack, Typography } from '@mui/material';
import { graphScopes, msalInstance } from './auth/authService';

const ConfigurationRequired: React.FC = () => (
  <main className="setup-page">
    <section className="setup-card" aria-labelledby="setup-title">
      <div className="brand-mark" aria-hidden="true">M</div>
      <p className="eyebrow">INTUNE HELPDESK</p>
      <h1 id="setup-title">Connect your helpdesk workspace</h1>
      <p className="setup-intro">
        The local app is running. Add your Microsoft Entra app settings to enable sign-in.
        No client secret belongs in this frontend.
      </p>
      <div className="setup-step">
        <span>1</span>
        <div>
          <strong>Create a local environment file</strong>
          <p>In the project folder, create <code>.env.local</code> with your SPA app values:</p>
          <pre>{'VITE_ENTRA_CLIENT_ID=your-application-client-id\nVITE_ENTRA_TENANT_ID=your-tenant-id'}</pre>
        </div>
      </div>
      <div className="setup-step">
        <span>2</span>
        <div>
          <strong>Register the local redirect URI</strong>
          <p>Add <code>http://localhost:5173/</code> as a Single-page application redirect URI.</p>
        </div>
      </div>
      <div className="setup-notice" role="status">
        Grant the Microsoft Graph delegated permission DeviceManagementManagedDevices.Read.All
        with administrator consent. Device data is read directly from Graph after sign-in;
        no local API is needed. Sync/wipe and BitLocker recovery additionally require
        DeviceManagementManagedDevices.PrivilegedOperations.All and BitlockerKey.Read.All.
      </div>
      <p className="setup-footer">Restart the development server after changing environment values.</p>
    </section>
  </main>
);

const Helpdesk: React.FC = () => {
  const { instance, inProgress, accounts } = useMsal();
  const authenticated = useIsAuthenticated();
  const [error, setError] = useState<string | null>(null);

  const signIn = async () => {
    setError(null);
    try {
      const result = await instance.loginPopup({ scopes: graphScopes });
      instance.setActiveAccount(result.account);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Microsoft sign-in failed.');
    }
  };

  const signOut = async () => {
    setError(null);
    try {
      await instance.logoutPopup({ account: instance.getActiveAccount() ?? accounts[0] });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Microsoft sign-out failed.');
    }
  };

  return (
    <Container component="main" maxWidth="lg" sx={{ py: 4 }}>
      <Typography variant="h4" component="h1" gutterBottom>Intune Helpdesk</Typography>
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
      {!authenticated ? (
        <Box>
          <Typography sx={{ mb: 2 }}>Sign in to view your organization's Intune devices.</Typography>
          <Button variant="contained" disabled={inProgress !== InteractionStatus.None} onClick={signIn}>
            Sign in with Microsoft
          </Button>
        </Box>
      ) : (
        <Router>
          <Stack direction="row" spacing={2} sx={{ mb: 3 }}>
            <Button component={Link} to="/">Dashboard</Button>
            <Button component={Link} to="/search">Search devices</Button>
            <Button onClick={signOut} disabled={inProgress !== InteractionStatus.None}>Sign out</Button>
          </Stack>
          <Alert severity="info" sx={{ mb: 3 }}>Device details include sync, Windows device wipe, and BitLocker recovery. Additional permissions and roles are required for these actions.</Alert>
            <Switch>
              <Route path="/" exact component={Dashboard} />
              <Route path="/search" component={DeviceSearch} />
              <Route path="/device/:id" component={DeviceDetails} />
              <Route component={Dashboard} />
            </Switch>
        </Router>
      )}
    </Container>
  );
};

const App: React.FC = () => {
  if (!msalInstance) {
    return <ConfigurationRequired />;
  }

  return (
    <MsalProvider instance={msalInstance}>
      <Helpdesk />
    </MsalProvider>
  );
};

export default App;