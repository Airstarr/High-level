import React, { useState, useEffect } from 'react';

function Toast({ message, type = 'info', duration = 3000 }) {
  const [isVisible, setIsVisible] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => {
      setIsVisible(false);
    }, duration);

    return () => clearTimeout(timer);
  }, [duration]);

  if (!isVisible) return null;

  return (
    <div className={`toast toast-${type}`}>
      <p>{message}</p>
    </div>
  );
}

export default Toast;
