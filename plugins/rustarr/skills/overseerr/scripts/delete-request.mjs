import { overseerrFetch, printJson, toInt } from './lib.mjs';

const id = toInt(process.argv[2], { name: 'request id' });
if (id === undefined) {
  process.stderr.write('Usage: node delete-request.mjs <request-id>\n');
  process.exit(2);
}

const result = await overseerrFetch(`/request/${id}`, { method: 'DELETE' });
printJson(result);
