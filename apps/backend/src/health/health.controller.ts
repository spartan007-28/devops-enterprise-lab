import { Controller, Get, HttpCode, HttpStatus, ServiceUnavailableException } from '@nestjs/common';
import { HealthService } from './health.service';

type HealthResponse = {
  status: 'ok';
  service: 'backend';
  checks?: { database: 'ok' };
};

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get('live')
  live(): HealthResponse {
    return { status: 'ok', service: 'backend' };
  }

  @Get('ready')
  @HttpCode(HttpStatus.OK)
  async ready(): Promise<HealthResponse> {
    const database = await this.healthService.checkDatabase();

    if (database !== 'ok') {
      throw new ServiceUnavailableException({
        status: 'error',
        service: 'backend',
        checks: { database: 'unavailable' },
      });
    }

    return { status: 'ok', service: 'backend', checks: { database: 'ok' } };
  }
}
