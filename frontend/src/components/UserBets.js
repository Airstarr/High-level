import React, { useState, useEffect } from 'react';
import { openContractCall } from '@stacks/connect';
import { StacksMainnet } from '@stacks/network';
import { callReadOnlyFunction, uintCV, principalCV } from '@stacks/transactions';

function UserBets({ userSession }) {
  const [userBets, setUserBets] = useState([]);

  useEffect(() => {
    const fetchUserBets = async () => {
      // In a real application, you'd fetch the list of market IDs first
      const marketIds = [1, 2, 3]; // Example market IDs
      const fetchedBets = await Promise.all(
        marketIds.map(async (id) => {
          const result = await callReadOnlyFunction({
            network: new StacksMainnet(),
            contractAddress: 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9',
            contractName: 'prediction-market',
            functionName: 'get-user-bets',
            functionArgs: [
              uintCV(id),
              principalCV(userSession.loadUserData().profile.stxAddress.mainnet)
            ],
            senderAddress: userSession.loadUserData().profile.stxAddress.mainnet,
          });
          return { marketId: id, ...result.value };
        })
      );
      setUserBets(fetchedBets.filter(bet => bet.yesAmount > 0 || bet.noAmount > 0));
    };

    fetchUserBets();
  }, [userSession]);

  const handleClaimPayout = async (marketId) => {
    const options = {
      network: new StacksMainnet(),
      contractAddress: 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9',
      contractName: 'prediction-market',
      functionName: 'claim-payout',
      functionArgs: [uintCV(marketId)],
      appDetails: {
        name: 'Prediction Market',
        icon: window.location.origin + '/logo.svg',
      },
      onFinish: (data) => {
        console.log('Transaction finished:', data);
      },
    };

    await openContractCall(options);
  };

  return (
    <div className="user-bets">
      <h2>Your Bets</h2>
      <ul>
        {userBets.map((bet) => (
          <li key={bet.marketId}>
            Market ID: {bet.marketId}
            <br />
            Yes Amount: {bet.yesAmount}
            <br />
            No Amount: {bet.noAmount}
            <br />
            <button onClick={() => handleClaimPayout(bet.marketId)}>
              Claim Payout
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default UserBets;
