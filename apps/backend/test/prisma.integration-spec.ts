import { PrismaClient } from '@prisma/client';

const runIntegrationTests = process.env.RUN_INTEGRATION_TESTS === '1';

(runIntegrationTests ? describe : describe.skip)('Prisma persistence integration', () => {
  let prisma: PrismaClient;
  let taskId: string;

  beforeAll(async () => {
    prisma = new PrismaClient();
    await prisma.$connect();
  });

  afterAll(async () => {
    if (taskId) {
      await prisma.task.delete({ where: { id: taskId } });
    }
    await prisma.$disconnect();
  });

  it('creates and reads a Task from PostgreSQL', async () => {
    const task = await prisma.task.create({ data: { title: 'container persistence check' } });
    taskId = task.id;

    await expect(prisma.task.findUnique({ where: { id: task.id } })).resolves.toMatchObject({
      id: task.id,
      title: 'container persistence check',
      completed: false,
    });
  });
});
