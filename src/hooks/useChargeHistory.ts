import { useState, useEffect } from 'react';
import { logger } from '../services/utils/logger';

interface Charge {
  id: string;
  amount: number;
  status: string;
  created: number;
  metadata: {
    order_id?: string;
  };
}

export function useChargeHistory(sellerId: string) {
  const [charges, setCharges] = useState<Charge[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchCharges() {
      try {
        setLoading(true);
        setError(null);

        const response = await fetch('/.netlify/functions/get-stripe-charges', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ sellerId }),
        });

        if (!response.ok) {
          throw new Error('Failed to fetch charges');
        }

        const data = await response.json();
        setCharges(data);
        
        logger.info('Fetched charges:', { count: data.length });
      } catch (err) {
        logger.error('Error fetching charges:', err);
        setError(err instanceof Error ? err.message : 'Failed to fetch charges');
      } finally {
        setLoading(false);
      }
    }

    if (sellerId) {
      fetchCharges();
    }
  }, [sellerId]);

  return { charges, loading, error };
}