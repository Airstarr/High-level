import React, { useState } from 'react';
import { openContractCall } from '@stacks/connect';
import { StacksMainnet } from '@stacks/network';
import { stringUtf8CV, uintCV } from '@stacks/transactions';

function MarketCreation({ userSession }) {
  const [description, setDescription] = useState('');
  const [resolutionTime, setResolutionTime] = useState('');

  const handleCreateMarket = async () => {
    const functionArgs = [
      stringUtf8CV(description),
      uintCV(Math.floor(new Date(resolutionTime).getTime() / 1000)),
    ];

    const options = {
      network: new StacksMainnet(),
      contractAddress: 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9',
      contractName: 'prediction-market',
      functionName: 'create-market',
      functionArgs,
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
    <div className="market-creation">
      <h2>Create New Market</h2>
      <input
        type="text"
        value={description}
        onChange={(e) => setDescription(e.target.value)}
        placeholder="Market description"
      />
      <input
        type="datetime-local"
        value={resolutionTime}
        onChange={(e) => setResolutionTime(e.target.value)}
      />
      <button onClick={handleCreateMarket}>Create Market</button>
    </div>
  );
}

export default MarketCreation;
