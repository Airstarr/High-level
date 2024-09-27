import React, { useState, useEffect } from 'react';
import { callReadOnlyFunction } from '@stacks/transactions';
import { StacksMainnet } from '@stacks/network';
import PlaceBet from './PlaceBet';

function MarketDetail({ marketId, userSession }) {
  const [marketInfo, setMarketInfo] = useState(null);

  useEffect(() => {
    const fetchMarketInfo = async () => {
      const result = await callReadOnlyFunction({
        network: new StacksMainnet(),
        contractAddress: 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9',
        contractName: 'prediction-market',
        functionName: 'get-market-info',
        functionArgs: [marketId],
      });
      setMarketInfo(result.value);
    };

    fetchMarketInfo();
  }, [marketId]);

  if (!marketInfo) return <div>Loading...</div>;

  return (
    <div className="market-detail">
      <h2>{marketInfo.description}</h2>
      <p>Creator: {marketInfo.creator}</p>
      <p>Resolution Time: {new Date(marketInfo.resolutionTimestamp * 1000).toLocaleString()}</p>
      <p>Total Yes Amount: {marketInfo.totalYesAmount}</p>
      <p>Total No Amount: {marketInfo.totalNoAmount}</p>
      <p>State: {marketInfo.state}</p>
      {marketInfo.outcome !== null && (
        <p>Outcome: {marketInfo.outcome ? 'Yes' : 'No'}</p>
      )}
      <PlaceBet marketId={marketId} userSession={userSession} />
    </div>
  );
}

export default MarketDetail;
