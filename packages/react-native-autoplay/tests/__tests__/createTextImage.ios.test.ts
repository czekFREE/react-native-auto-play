import { createTextImage } from '../../src/utils/createTextImage';

describe('createTextImage', () => {
  it('provides a local themed bitmap descriptor for an arbitrary count', () => {
    expect(createTextImage({ text: '1248' })).toEqual({
      type: 'asset',
      color: { darkColor: 'white', lightColor: 'black' },
      image: {
        uri: 'autoplay-internal://text-image/1248',
        width: 128,
        height: 128,
        scale: 1,
      },
    });
  });

  it('encodes Unicode and URI punctuation as text instead of a resource address', () => {
    expect(createTextImage({ text: 'Č / ? %', color: 'red' })).toMatchObject({
      color: 'red',
      image: { uri: 'autoplay-internal://text-image/%C4%8C%20%2F%20%3F%20%25' },
    });
  });

  it('preserves the original descriptor for an explicit full-size scale', () => {
    expect(createTextImage({ text: 'A', fontScale: 1 })).toEqual({
      type: 'asset',
      color: { darkColor: 'white', lightColor: 'black' },
      image: {
        uri: 'autoplay-internal://text-image/A',
        width: 128,
        height: 128,
        scale: 1,
      },
    });
  });

  it('scales text within the same canvas without treating punctuation as query data', () => {
    expect(createTextImage({ text: 'Č / ? %', fontScale: 0.65 })).toEqual({
      type: 'asset',
      color: { darkColor: 'white', lightColor: 'black' },
      image: {
        uri: 'autoplay-internal://text-image/%C4%8C%20%2F%20%3F%20%25?fontScale=0.65',
        width: 128,
        height: 128,
        scale: 1,
      },
    });
  });

  it('provides untinted white-circle artwork at the default font scale', () => {
    expect(createTextImage({ text: '1248', background: 'whiteCircle' })).toEqual({
      type: 'asset',
      image: {
        uri: 'autoplay-internal://text-image/1248?background=whiteCircle',
        width: 128,
        height: 128,
        scale: 1,
      },
    });
  });

  it('combines a white circle with reduced text and preserves query punctuation as text', () => {
    expect(
      createTextImage({ text: 'Č / ? % & =', fontScale: 0.65, background: 'whiteCircle' }),
    ).toEqual({
      type: 'asset',
      image: {
        uri: 'autoplay-internal://text-image/%C4%8C%20%2F%20%3F%20%25%20%26%20%3D?fontScale=0.65&background=whiteCircle',
        width: 128,
        height: 128,
        scale: 1,
      },
    });
  });

  it.each([0, -0.5, 1.01, Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY])(
    'rejects invalid font scale %s before crossing the native boundary',
    (fontScale) => {
      expect(() => createTextImage({ text: '128', fontScale })).toThrow(
        'createTextImage() fontScale must be greater than 0 and at most 1',
      );
    },
  );

  it('allows an empty image and the maximum supported text length', () => {
    expect(createTextImage({ text: '' })).toMatchObject({
      image: { uri: 'autoplay-internal://text-image/' },
    });
    expect(() => createTextImage({ text: 'a'.repeat(128) })).not.toThrow();
  });

  it('rejects oversized text before crossing the native boundary', () => {
    expect(() => createTextImage({ text: 'a'.repeat(129) })).toThrow(
      'createTextImage() text must contain at most 128 UTF-16 code units',
    );
  });
});
