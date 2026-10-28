export interface EvaluationCase {
  id: string;
  question: string;
  expectedDocumentKey?: string;
  expectedStatus: 'answered' | 'insufficient_evidence';
  checklist: string[];
}

export interface EvaluationDataset {
  version: number;
  questions: EvaluationCase[];
  negativeQuestions: EvaluationCase[];
  integrationCases: { id: string; category: string; description: string; test: string; expected: string }[];
}

export function percentile(samples: number[], fraction: number): number | null {
  if (!samples.length) return null;
  const ordered = [...samples].sort((left, right) => left - right);
  return ordered[Math.max(0, Math.ceil(ordered.length * fraction) - 1)];
}

export function automatedGate(input: {
  positiveHits: number; answeredPositives: number; negativeFallbacks: number;
  softwarePassed: boolean; warmLatencies: number[]; timeouts: number;
}) {
  return input.positiveHits >= 14 && input.answeredPositives >= 13 && input.negativeFallbacks === 5 &&
    input.softwarePassed && input.warmLatencies.length >= 30 && input.timeouts === 0 &&
    (percentile(input.warmLatencies, 0.95) ?? Infinity) <= 30_000;
}
