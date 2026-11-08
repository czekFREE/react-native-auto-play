import type { ImageRow } from '../../src/templates/ListTemplate';
import { NitroSectionUtil } from '../../src/utils/NitroSection';
import { HybridListTemplate } from '../../src/utils/HybridListTemplate';

jest.mock('../../src/utils/HybridListTemplate', () => ({
  HybridListTemplate: { completeListItemPress: jest.fn() },
}));
jest.mock('react-native', () => ({
  Image: { resolveAssetSource: jest.fn() },
  processColor: jest.fn(),
}));

const template = { id: 'for-you' };

const createTrackRow = ({
  onPress,
}: {
  onPress: (context: typeof template) => Promise<void> | void;
}): ImageRow<typeof template> => ({
  type: 'image',
  id: 'queue',
  title: { text: 'Bude hrát' },
  variant: 'condensed',
  items: [
    {
      id: 'track-42',
      image: { type: 'remote', uri: 'https://example.com/episode.png' },
      imageShape: 'roundedRectangle',
      title: { text: 'Episode headline' },
      subtitle: { text: 'Podcast name' },
      playbackDuration: 180,
      playbackElapsedTime: 24,
      onPress,
    },
  ],
});

describe('NitroSection image-element playback', () => {
  beforeEach(() => jest.clearAllMocks());

  it('marks only the explicit pagination row for native identity handoff', () => {
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [
        { type: 'default', id: 'track-1', title: { text: 'Track' }, onPress: jest.fn() },
        {
          type: 'default',
          id: 'more',
          title: { text: 'Načíst další' },
          isPaginationItem: true,
          onPress: jest.fn(),
        },
      ],
    });
    expect(
      result?.[0]?.items.map(({ id, isPaginationItem }) => ({ id, isPaginationItem })),
    ).toEqual([
      { id: 'track-1', isPaginationItem: undefined },
      { id: 'more', isPaginationItem: true },
    ]);
  });

  it('sends stable track identity and native playback times with the correct tile', () => {
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [createTrackRow({ onPress: jest.fn() })],
    });

    expect(result?.[0]?.items[0]).toMatchObject({
      id: 'queue',
      imageRowVariant: 'condensed',
      imageRowItems: [
        {
          id: 'track-42',
          title: 'Episode headline',
          subtitle: 'Podcast name',
          image: { uri: 'https://example.com/episode.png' },
          playbackDuration: 180,
          playbackElapsedTime: 24,
        },
      ],
    });
  });

  it('leaves ordinary show cards non-playable', () => {
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [
        {
          type: 'image',
          title: { text: 'Odebírané podcasty' },
          items: [
            {
              title: { text: 'Podcast' },
              image: { type: 'remote', uri: 'https://example.com/show.png' },
            },
          ],
        },
      ],
    });

    expect(result?.[0]?.items[0]?.imageRowItems?.[0]).toMatchObject({
      title: 'Podcast',
      playbackDuration: undefined,
      playbackElapsedTime: undefined,
    });
  });

  it('keeps an image-free condensed action selectable without playback metadata', async () => {
    const onPress = jest.fn();
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [
        {
          type: 'image',
          title: { text: '' },
          variant: 'condensed',
          items: [
            {
              id: 'show-all',
              title: { text: 'Zobrazit vše' },
              imageShape: 'roundedRectangle',
              accessorySystemImage: 'chevron.right',
              onPress,
            },
          ],
        },
      ],
    });
    const action = result?.[0]?.items[0]?.imageRowItems?.[0];

    expect(action).toMatchObject({
      id: 'show-all',
      title: 'Zobrazit vše',
      accessorySystemImage: 'chevron.right',
      image: {
        uri: 'autoplay-internal://empty-image',
        width: 0,
        height: 0,
        scale: 1,
        packager_asset: false,
      },
      playbackDuration: undefined,
      playbackElapsedTime: undefined,
    });
    action?.onPress?.('show-all-selection');
    await Promise.resolve();

    expect(onPress).toHaveBeenCalledWith({ id: 'for-you' });
    expect(HybridListTemplate.completeListItemPress).toHaveBeenCalledWith('show-all-selection');
  });

  it('keeps an explicit artwork URL distinct from intentional empty artwork', () => {
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [createTrackRow({ onPress: jest.fn() })],
    });

    expect(result?.[0]?.items[0]?.imageRowItems?.[0]?.image).toEqual({
      uri: 'https://example.com/episode.png',
      color: undefined,
      timeoutMs: undefined,
    });
  });

  it('finishes the native tile selection only after asynchronous playback settles', async () => {
    let completePlayback: () => void = () => undefined;
    const playback = new Promise<void>((resolve) => {
      completePlayback = resolve;
    });
    const onPress = jest.fn(() => playback);
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [createTrackRow({ onPress })],
    });

    result?.[0]?.items[0]?.imageRowItems?.[0]?.onPress?.('selection-42');

    expect(onPress).toHaveBeenCalledWith({ id: 'for-you' });
    expect(HybridListTemplate.completeListItemPress).not.toHaveBeenCalled();
    completePlayback();
    await playback;
    await Promise.resolve();

    expect(HybridListTemplate.completeListItemPress).toHaveBeenCalledWith('selection-42');
  });

  it('also completes the native selection when playback rejects', async () => {
    const result = NitroSectionUtil.convert(template, {
      type: 'default',
      items: [createTrackRow({ onPress: () => Promise.reject(new Error('Playback failed')) })],
    });

    result?.[0]?.items[0]?.imageRowItems?.[0]?.onPress?.('failed-selection');
    await Promise.resolve();
    await Promise.resolve();

    expect(HybridListTemplate.completeListItemPress).toHaveBeenCalledWith('failed-selection');
  });
});
