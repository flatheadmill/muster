const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Run the real request-building path with only the transport replaced.
const source = fs.readFileSync(path.join(__dirname, '../bin/codex-nudge'), 'utf8')
    .replace(/^#!.*\n/, '');
const program = source.slice(0, source.lastIndexOf('\nmain().catch'));

async function run(config, start = false) {
    const requests = [];
    const processStub = {
        argv: ['node', 'codex-nudge', '--socket', '/test.sock',
            '--resume-config', JSON.stringify(config),
            ...(start ? ['--start-thread'] : ['--thread', 'test-thread', 'Review this.'])],
        stdout: { write() {} },
        stderr: { write() {} },
    };
    const rpc = {
        notify() {},
        async request(method, params) {
            requests.push({ method, params });
            if (method === 'initialize' || method === 'thread/inject_items') return {};
            if (method === 'thread/start' || method === 'thread/resume') {
                return { thread: { id: 'test-thread', ephemeral: false } };
            }
            if (method === 'turn/start') return { turn: { id: 'test-turn', status: 'inProgress' } };
            throw new Error(`Unexpected RPC: ${method}`);
        },
    };
    const execute = new Function('require', 'rpc', `${program}
        openUnixWebSocket = async () => ({ websocket: {}, close() {} });
        rpcClient = () => rpc;
        return main();
    `);
    await execute(name => name === 'node:process' ? processStub : require(name), rpc);
    return requests;
}

(async () => {
    const config = { model: 'gpt-6-astra', serviceTier: 'fast',
        config: { model_reasoning_effort: 'max' } };
    const started = await run(config, true);
    assert.deepEqual(started.find(r => r.method === 'thread/start').params.config,
        { model_reasoning_effort: 'max' });
    const nudged = await run(config);
    const turn = nudged.find(r => r.method === 'turn/start').params;
    assert.equal(turn.model, 'gpt-6-astra');
    assert.equal(turn.effort, 'max');
    assert.equal(turn.serviceTier, 'fast');
    const inherited = await run({ model: 'gpt-5.6-sol', config: {} });
    const inheritedTurn = inherited.find(r => r.method === 'turn/start').params;
    assert.equal(Object.hasOwn(inheritedTurn, 'effort'), false);
    assert.equal(Object.hasOwn(inheritedTurn, 'serviceTier'), false);
    console.log('Codex start and nudge preserve configured effort and service tier.');
})().catch(error => { console.error(error); process.exitCode = 1; });
