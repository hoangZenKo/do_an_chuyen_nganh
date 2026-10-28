import { NestFactory } from '@nestjs/core';

import { configureApp } from './app.bootstrap';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = configureApp(await NestFactory.create(AppModule));
  await app.listen(Number(process.env.PORT ?? 3000));
}

void bootstrap();
