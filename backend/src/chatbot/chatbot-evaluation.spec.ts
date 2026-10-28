import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { automatedGate, EvaluationDataset, percentile } from './chatbot-evaluation';

describe('MVP evaluation gate', () => {
  const baseline = { positiveHits: 14, answeredPositives: 13, negativeFallbacks: 5,
    softwarePassed: true, warmLatencies: Array(30).fill(20000), timeouts: 0 };
  it('has exactly 30 unique cases and checklists for all model questions', () => {
    const data = JSON.parse(readFileSync(resolve('test/evals/chatbot-mvp-vi.json'), 'utf8')) as EvaluationDataset;
    expect(data.questions).toHaveLength(15);
    expect(data.negativeQuestions).toHaveLength(5);
    expect(data.integrationCases.filter((entry) => entry.category === 'security')).toHaveLength(5);
    expect(data.integrationCases.filter((entry) => entry.category === 'lifecycle')).toHaveLength(5);
    const cases = [...data.questions, ...data.negativeQuestions, ...data.integrationCases];
    expect(new Set(cases.map((entry) => entry.id)).size).toBe(30);
    expect(data.questions.every((entry) => entry.checklist.length > 0 && entry.expectedDocumentKey)).toBe(true);
  });
  it('uses nearest-rank percentiles and never treats no samples as zero latency', () => {
    expect(percentile([], 0.95)).toBeNull();
    expect(percentile([40, 10, 20, 30], 0.5)).toBe(20);
    expect(percentile([40, 10, 20, 30], 0.95)).toBe(40);
  });
  it('requires sample count, retrieval, fallback, security and latency thresholds', () => {
    expect(automatedGate(baseline)).toBe(true);
    for (const override of [{ positiveHits: 13 }, { answeredPositives: 12 }, { negativeFallbacks: 4 },
      { softwarePassed: false }, { warmLatencies: [1000] }, { warmLatencies: Array(30).fill(31000) }, { timeouts: 1 }]) {
      expect(automatedGate({ ...baseline, ...override })).toBe(false);
    }
  });
});
