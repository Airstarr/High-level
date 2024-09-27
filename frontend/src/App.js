import React, { useState, useEffect } from 'react';
import { AppConfig, UserSession, showConnect } from '@stacks/connect';
import MarketCreation from './components/MarketCreation';
import MarketList from './components/MarketList';
import MarketDetail from './components/MarketDetail';
import UserBets from './components/UserBets';
import Loading from './components/Loading';
import ErrorBoundary from './components/ErrorBoundary';
import Toast from './components/Toast';

const appConfig = new AppConfig(['store_write', 'publish_data']);
const userSession = new UserSession({ appConfig });

function App() {
  const [userData, setUserData] = useState(null);
  const [selectedMarket, setSelectedMarket] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [toast, setToast] = useState(null);

  useEffect(() => {
    if (userSession.isSignInPending()) {
      userSession.handlePendingSignIn().then((userData) => {
        setUserData(userData);
        setIsLoading(false);
      });
    } else if (userSession.isUserSignedIn()) {
      setUserData(userSession.loadUserData());
      setIsLoading(false);
    } else {
      setIsLoading(false);
    }
  }, []);

  const handleSignIn = () => {
    showConnect({
      appDetails: {
        name: 'Prediction Market',
        icon: window.location.origin + '/logo.svg',
      },
      redirectTo: '/',
      onFinish: () => {
        setUserData(userSession.loadUserData());
        setToast({ message: 'Successfully signed in!', type: 'success' });
      },
    });
  };

  const handleSignOut = () => {
    userSession.signUserOut(window.location.origin);
    setUserData(null);
    setToast({ message: 'Successfully signed out', type: 'info' });
  };

  if (isLoading) return <Loading />;

  return (
    <ErrorBoundary>
      <div className="app">
        <header>
          <h1>Prediction Market</h1>
          {userData ? (
            <button onClick={handleSignOut}>Sign Out</button>
          ) : (
            <button onClick={handleSignIn}>Sign In with Stacks</button>
          )}
        </header>
        <main>
          {userData ? (
            <>
              <MarketCreation 
                userSession={userSession} 
                onSuccess={() => setToast({ message: 'Market created successfully!', type: 'success' })}
              />
              <MarketList onSelectMarket={setSelectedMarket} />
              {selectedMarket && (
                <MarketDetail
                  marketId={selectedMarket}
                  userSession={userSession}
                  onBetPlaced={() => setToast({ message: 'Bet placed successfully!', type: 'success' })}
                />
              )}
              <UserBets 
                userSession={userSession}
                onPayoutClaimed={() => setToast({ message: 'Payout claimed successfully!', type: 'success' })}
              />
            </>
          ) : (
            <p>Please sign in to use the Prediction Market.</p>
          )}
        </main>
        {toast && <Toast message={toast.message} type={toast.type} />}
      </div>
    </ErrorBoundary>
  );
}

export default App;
