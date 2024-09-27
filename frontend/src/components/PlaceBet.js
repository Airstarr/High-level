import React, { useState } from 'react';
import { openContractCall } from '@stacks/connect';
import { StacksMainnet } from '@stacks/network';
import { uintCV, trueCV, falseCV } from '@stacks/transactions';

function PlaceBet({ marketId, userSession }) {
  const [betAmount, setBetAmount] = useState('');
  const [betYes, setBetYes] = useState(true);

  const handlePlaceBet = async () => {
    const functionArgs = [
      uintCV(marketId),
      betYes ? trueCV() : falseCV(),
      uintCV(parseInt(betAmount, 10)),
    ];

    const options = {
      network: new StacksMainnet(),
      contractAddress: 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9',
      contractName: 'prediction-market',
      functionName: 'place-bet',
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
    <div className="place-bet">
      <h3>Place Your Bet</h3>
      <input
        type="number"
        value={betAmount}
        onChange={(e) => setBetAmount(e.target.value)}
        placeholder="Bet amount (in STX)"
      />
      <div>
        <label>
          <input
            type="radio"
            checked={betYes}
            onChange={() => setBetYes(true)}
          />
          Yes
        </label>
        <label>
          <input
            type="radio"
            checked={!betYes}
            onChange={() => setBetYes(false)}
          />
          No
        </label>
      </div>
      <button onClick={handlePlaceBet}>Place Bet</button>
    </div>
  );
}

export default PlaceBet;
