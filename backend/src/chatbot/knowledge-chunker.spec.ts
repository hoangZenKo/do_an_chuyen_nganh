import { chunkMarkdown } from './knowledge-chunker';

describe('chunkMarkdown', () => {
  it('preserves headings and normalizes line endings', () => {
    expect(chunkMarkdown('# Guide\r\n\r\nIntro.\r\n## Create\r\nOpen Billing.')).toEqual([
      { ordinal: 0, heading: 'Guide', text: 'Intro.' },
      { ordinal: 1, heading: 'Guide > Create', text: 'Open Billing.' },
    ]);
  });
  it('bounds long paragraphs and retains all content in order with overlap', () => {
    const text = Array.from({ length: 1000 }, (_, index) => `word${index}`).join(' ');
    const chunks = chunkMarkdown(`# Long\n${text}`);
    expect(chunks.length).toBeGreaterThan(1);
    for (const [index, chunk] of chunks.entries()) {
      expect(chunk.ordinal).toBe(index);
      expect(chunk.heading).toBe('Long');
      expect(chunk.text.length).toBeLessThanOrEqual(1200);
      expect(text).toContain(chunk.text);
    }
    for (const word of text.split(' ')) expect(chunks.some((chunk) => chunk.text.includes(word))).toBe(true);
    expect(chunks.at(-1)?.text).toContain('word999');
  });
  it('handles an unbroken string and ignores headings inside fenced code', () => {
    expect(chunkMarkdown('x'.repeat(4000)).every((chunk) => chunk.text.length <= 1200)).toBe(true);
    const chunks = chunkMarkdown('# Guide\n```sh\n# shell comment\necho hello\n```\n## Next\nDone');
    expect(chunks[0].heading).toBe('Guide');
    expect(chunks[0].text).toContain('# shell comment');
    expect(chunks[1].heading).toBe('Guide > Next');
  });
  it('excludes editorial HTML comments from searchable text', () => {
    expect(chunkMarkdown('# Guide\n<!-- Reviewer note is not user-facing. -->\nActual procedure.'))
      .toEqual([{ ordinal: 0, heading: 'Guide', text: 'Actual procedure.' }]);
    expect(chunkMarkdown('# Guide\n<!-- multiline\nnot searchable\n-->\nActual procedure.'))
      .toEqual([{ ordinal: 0, heading: 'Guide', text: 'Actual procedure.' }]);
  });
  it('rejects empty, heading-only, binary and oversize content', () => {
    for (const content of ['', ' ', '# Title', 'hello\0world', 'x'.repeat(50001)]) {
      expect(() => chunkMarkdown(content)).toThrow('KNOWLEDGE_INVALID_CONTENT');
    }
  });
});
