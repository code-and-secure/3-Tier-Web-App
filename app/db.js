const sql = require('mssql');

const config = {
  server: process.env.SQL_SERVER,
  database: process.env.SQL_DATABASE,
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  port: 1433,
  options: {
    encrypt: true,
    trustServerCertificate: false,
  },
};

let poolPromise;

function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config)
      .connect()
      .then(async (pool) => {
        await pool.request().query(`
          IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='GuestbookEntries' AND xtype='U')
          CREATE TABLE GuestbookEntries (
            Id INT IDENTITY PRIMARY KEY,
            Name NVARCHAR(100) NOT NULL,
            Email NVARCHAR(200) NOT NULL,
            Message NVARCHAR(1000) NOT NULL,
            CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
          )
        `);
        return pool;
      });
  }
  return poolPromise;
}

async function listEntries() {
  const pool = await getPool();
  const result = await pool
    .request()
    .query('SELECT TOP 50 Name, Email, Message, CreatedAt FROM GuestbookEntries ORDER BY CreatedAt DESC');
  return result.recordset;
}

async function addEntry({ name, email, message }) {
  const pool = await getPool();
  await pool
    .request()
    .input('name', sql.NVarChar(100), name)
    .input('email', sql.NVarChar(200), email)
    .input('message', sql.NVarChar(1000), message)
    .query('INSERT INTO GuestbookEntries (Name, Email, Message) VALUES (@name, @email, @message)');
}

module.exports = { listEntries, addEntry };
