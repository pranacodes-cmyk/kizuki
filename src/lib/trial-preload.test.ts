import { beforeEach, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ api: vi.fn(), content: vi.fn(), notes: vi.fn() }));
vi.mock('./youtube', () => ({ loadYouTubeApi: mocks.api }));
vi.mock('./content', () => ({ loadContent: mocks.content, loadNotes: mocks.notes, thumbOf: () => '/starter-poster.jpg' }));

beforeEach(() => { vi.resetModules(); vi.clearAllMocks(); });

it('prepares starter content and notes while the YouTube bootstrap is still loading', async () => {
  let complete: (() => void) | undefined;
  mocks.api.mockReturnValue(new Promise<void>(resolve => { complete = resolve; }));
  mocks.content.mockResolvedValue({ starter: [{ id: 'first' }], byId: { first: { id: 'first', videoId: 'video' } } });
  mocks.notes.mockResolvedValue({});
  const { preloadTrial } = await import('./trial-preload');
  const preparation = preloadTrial();
  expect(mocks.api).toHaveBeenCalledTimes(1);
  expect(mocks.content).toHaveBeenCalledTimes(1);
  await vi.waitFor(() => expect(mocks.notes).toHaveBeenCalledWith('first'));
  expect(document.querySelector('iframe')).toBeNull();
  complete?.();
  await preparation;
});