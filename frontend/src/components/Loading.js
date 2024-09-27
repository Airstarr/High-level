import React from 'react';

function Loading() {
  return (
    <div className="loading">
      <svg width="50" height="50" viewBox="0 0 50 50">
        <circle cx="25" cy="25" r="20" fill="none" strokeWidth="5" stroke="#3498db">
          <animate attributeName="stroke-dasharray" dur="1.5s" repeatCount="indefinite"
                   from="0 140" to="140 140"/>
          <animate attributeName="stroke-dashoffset" dur="1.5s" repeatCount="indefinite"
                   from="0" to="-140"/>
        </circle>
      </svg>
      <p>Loading...</p>
    </div>
  );
}

export default Loading;
