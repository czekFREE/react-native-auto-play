import type { AutoImage } from '../types/Image';
import type { ThemedColor } from './NitroColor';

type TextImageOptions = {
  text: string;
  fontScale?: number;
} & (
  | { background?: undefined; color?: ThemedColor | string }
  | { background: 'whiteCircle'; color?: never }
);

/** Draws local text artwork without mounting a React Native view. @namespace iOS */
export const createTextImage = ({
  text,
  color = { darkColor: 'white', lightColor: 'black' },
  fontScale = 1,
  background,
}: TextImageOptions): AutoImage => {
  if (text.length > 128) {
    throw new Error('createTextImage() text must contain at most 128 UTF-16 code units');
  }
  if (!Number.isFinite(fontScale) || fontScale <= 0 || fontScale > 1) {
    throw new Error('createTextImage() fontScale must be greater than 0 and at most 1');
  }

  const query = [
    ...(fontScale === 1 ? [] : [`fontScale=${fontScale}`]),
    ...(background === 'whiteCircle' ? ['background=whiteCircle'] : []),
  ].join('&');

  return {
    type: 'asset',
    ...(background === 'whiteCircle' ? {} : { color }),
    image: {
      uri: `autoplay-internal://text-image/${encodeURIComponent(text)}${query ? `?${query}` : ''}`,
      width: 128,
      height: 128,
      scale: 1,
    },
  };
};
