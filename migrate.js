const { Client } = require('./node_modules/.pnpm/pg@8.21.0/node_modules/pg');

const connectionString = 'postgresql://postgres:MNymGRyPgstRCHVtGSXpQXwfcLBhFVhk@reseau.proxy.rlwy.net:29879/railway';

async function migrate() {
  const client = new Client({ connectionString });
  await client.connect();
  
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS task_assignees (
        id SERIAL PRIMARY KEY,
        "taskId" INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        "userId" TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
        "assignedAt" TIMESTAMP NOT NULL DEFAULT NOW(),
        UNIQUE("taskId", "userId")
      )
    `);
    console.log('SUCCESS: task_assignees table created');
  } catch (err) {
    console.error('ERROR:', err.message);
  } finally {
    await client.end();
  }
}

migrate();
