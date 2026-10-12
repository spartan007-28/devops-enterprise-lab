import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Health endpoints', () => {
  let app: INestApplication;
  const queryRaw = jest.fn().mockResolvedValue([{ result: 1 }]);

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ $queryRaw: queryRaw })
      .compile();
    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health/live reports that the service is alive', async () => {
    await request(app.getHttpServer())
      .get('/health/live')
      .expect(200)
      .expect({ status: 'ok', service: 'backend' });
  });

  it('GET /health/ready reports readiness without a database dependency', async () => {
    await request(app.getHttpServer())
      .get('/health/ready')
      .expect(200)
      .expect({
        status: 'ok',
        service: 'backend',
        checks: { database: 'ok' },
      });
  });

  it('GET /health/ready returns 503 when the database check fails', async () => {
    queryRaw.mockRejectedValueOnce(new Error('database unavailable'));

    await request(app.getHttpServer())
      .get('/health/ready')
      .expect(503)
      .expect({
        status: 'error',
        service: 'backend',
        checks: { database: 'unavailable' },
      });
  });
});
