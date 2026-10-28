import { ChatbotError } from './chatbot.types';

export interface TextChunk {
  ordinal: number;
  heading: string;
  text: string;
}

export function normalizeKnowledgeText(text: string): string {
  if (typeof text !== 'string' || text.includes('\0') || text.length > 50000) {
    throw new ChatbotError('KNOWLEDGE_INVALID_CONTENT');
  }
  return text.replace(/^\uFEFF/, '').replace(/\r\n?/g, '\n').normalize('NFC').trim();
}

export function chunkMarkdown(markdown: string): TextChunk[] {
  const content = normalizeKnowledgeText(markdown);
  const chunks: TextChunk[] = [];
  let headings: string[] = [];
  let lines: string[] = [];
  let fence = '';
  let htmlComment = false;

  const flush = () => {
    const text = lines.join('\n').trim();
    lines = [];
    let start = 0;
    while (start < text.length) {
      let end = Math.min(start + 1200, text.length);
      if (end < text.length) {
        const paragraphEnd = text.lastIndexOf('\n\n', end);
        const spaceEnd = text.lastIndexOf(' ', end);
        if (paragraphEnd > start + 600) end = paragraphEnd;
        else if (spaceEnd > start + 600) end = spaceEnd;
        if (/[\uD800-\uDBFF]/.test(text[end - 1])) end--;
      }
      const fragment = text.slice(start, end).trim();
      if (fragment) chunks.push({ ordinal: chunks.length, heading: headings.filter(Boolean).join(' > '), text: fragment });
      if (end >= text.length) break;
      start = Math.max(start + 1, end - 150);
      if (/[\uDC00-\uDFFF]/.test(text[start])) start++;
    }
  };

  for (const line of content.split('\n')) {
    const fenceMatch = line.match(/^\s*(`{3,}|~{3,})/);
    if (fenceMatch) {
      if (!fence) fence = fenceMatch[1];
      else if (fenceMatch[1][0] === fence[0] && fenceMatch[1].length >= fence.length) fence = '';
      lines.push(line);
      continue;
    }
    if (fence) {
      lines.push(line);
      continue;
    }
    if (htmlComment || line.includes('<!--')) {
      htmlComment = !line.includes('-->') || line.indexOf('-->') < line.indexOf('<!--');
      continue;
    }
    const heading = line.match(/^(#{1,6})\s+(.+?)\s*#*$/);
    if (heading) {
      flush();
      headings = headings.slice(0, heading[1].length - 1);
      headings[heading[1].length - 1] = heading[2];
    } else lines.push(line);
  }
  flush();
  if (!chunks.length) throw new ChatbotError('KNOWLEDGE_INVALID_CONTENT');
  return chunks;
}
