import { check } from 'k6';
import http from 'k6/http';
import redis from 'k6/experimental/redis';
import exec from 'k6/execution';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

export const options = {
  scenarios: {
    redisPerformance: {
      executor: 'shared-iterations',
      vus: 10,
      iterations: 200,
      exec: 'measureRedisPerformance',
    },
    usingRedisData: {
      executor: 'shared-iterations',
      vus: 10,
      iterations: 200,
      exec: 'measureUsingRedisData',
    },
  },
};

// Instantiate a new redis client
const redisClient = new redis.Client({
    socket:{
        host: 'argo-workflows-redis-ephemeral-headless',
        port: 26379,
    },
    masterName: 'mymaster'
});

// Prepare an array of crocodile ids for later use
// in the context of the measureUsingRedisData function.
const crocodileIDs = new Array(0, 1, 2, 3, 4, 5, 6, 7, 8, 9);

export async function measureRedisPerformance() {
  // VUs are executed in a parallel fashion,
  // thus, to ensure that parallel VUs are not
  // modifying the same key at the same time,
  // we use keys indexed by the VU id.
  const key = `foo-${exec.vu.idInTest}`;

  await redisClient.set(key, 1);
  await redisClient.incrBy(key, 10);
  const value = await redisClient.get(key);
  if (value !== '11') {
    throw new Error('foo should have been incremented to 11');
  }

  await redisClient.del(key);
  if ((await redisClient.exists(key)) !== 0) {
    throw new Error('foo should have been deleted');
  }
}

export async function setup() {
  await redisClient.sadd('crocodile_ids', ...crocodileIDs);
}

export async function measureUsingRedisData() {
  // Pick a random crocodile id from the dedicated redis set,
  // we have filled in setup().
  const randomID = await redisClient.srandmember('crocodile_ids');
  const url = `https://test-api.k6.io/public/crocodiles/${randomID}`;
  const res = await http.asyncRequest('GET', url);

  check(res, { 'status is 200': (r) => r.status === 200 });

  await redisClient.hincrby('k6_crocodile_fetched', url, 1);
}

export async function teardown() {
  await redisClient.del('crocodile_ids');
}

export function handleSummary(data) {
  redisClient
    .hgetall('k6_crocodile_fetched')
    .then((fetched) => Object.assign(data, { k6_crocodile_fetched: fetched }))
    .then((data) => redisClient.set(`k6_report_${Date.now()}`, JSON.stringify(data)))
    .then(() => redisClient.del('k6_crocodile_fetched'));

  return {
    stdout: textSummary(data, { indent: '  ', enableColors: true }),
  };
}