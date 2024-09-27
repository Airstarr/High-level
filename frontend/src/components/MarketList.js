import React, { useState, useEffect } from 'react';
import { callReadOnlyFunction } from '@stacks/transactions';
import { StacksMainnet } from '@stacks/network';

function MarketList({ onSelectMarket }) {
  const [markets, setMarkets] = useState([]);

  useEffect(() => {
    const fetchMarkets = async () => {
      // In a real application, you'd fetch the list of market IDs first
      const marketIds = [1, 2, 3]; // Example market IDs
      const fetchedMarkets = await Promise.all(
        marketIds.map(async (id) => {
          const result = await callReadOnlyFunction({
            network: new StacksMainnet(),
            contractAddress: 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9',
            contractName: 'prediction-market',
            functionName: 'get-market-info',
            functionArgs: [id],
          });
          return { id, ...result.value };
        })
      );
      setMarkets(fetchedMarkets);
    };

    fetchMarkets();
  }, []);

  return (
    <div className="market-list">
      <h2>Active Markets</h2>
      <ul>
        {markets.map((market) => (
          <li key={market.id} onClick={() => onSelectMarket(market.id)}>
            {market.description}
          </li>
        ))}
      </ul>
    </div>
  );
}

export default MarketList;
