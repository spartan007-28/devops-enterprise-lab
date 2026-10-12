import { HealthService } from '../src/health/health.service';

describe('HealthService', () => {
  it('reports database availability after a successful query', async () => {
    const prisma = { $queryRaw: jest.fn().mockResolvedValue([{ result: 1 }]) };
    const service = new HealthService(prisma as never);

    await expect(service.checkDatabase()).resolves.toBe('ok');
  });

  it('reports database unavailability when the query fails', async () => {
    const prisma = { $queryRaw: jest.fn().mockRejectedValue(new Error('offline')) };
    const service = new HealthService(prisma as never);

    await expect(service.checkDatabase()).resolves.toBe('unavailable');
  });
});
