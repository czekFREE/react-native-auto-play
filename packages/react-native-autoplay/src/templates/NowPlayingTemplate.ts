import { HybridAutoPlay } from '../hybrid/HybridAutoPlay';
import type { AutoImage } from '../types/Image';
import type { NitroAction } from '../utils/NitroAction';
import { NitroImageUtil } from '../utils/NitroImage';

const NOW_PLAYING_BUTTON_SELECTED_FLAG = 1;

const noop = () => undefined;

export type NowPlayingSystemButtonType =
  | 'shuffle'
  | 'addToLibrary'
  | 'more'
  | 'playbackRate'
  | 'repeat';

type NowPlayingButtonBase = {
  enabled?: boolean;
  selected?: boolean;
  onPress: () => void;
};

export type NowPlayingSystemButton = NowPlayingButtonBase & {
  type: NowPlayingSystemButtonType;
};

export type NowPlayingImageButton = NowPlayingButtonBase & {
  type: 'image';
  image: AutoImage;
};

export type NowPlayingButton = NowPlayingSystemButton | NowPlayingImageButton;

export type IosNowPlayingTemplateConfig = {
  upNextButton?: {
    enabled?: boolean;
    title?: string;
    onPress?: () => void;
  };
  albumArtistButton?: {
    enabled?: boolean;
    onPress?: () => void;
  };
  buttons?: Array<NowPlayingButton>;
};

export type AndroidNowPlayingTemplateConfig = {
  mediaSession?: never;
};

export type NowPlayingTemplateConfig = {
  ios?: IosNowPlayingTemplateConfig;
  android?: AndroidNowPlayingTemplateConfig;
};

export type NowPlayingTemplateShowOptions = {
  animated?: boolean;
  config?: NowPlayingTemplateConfig;
};

const getNowPlayingButtonImage = ({ button }: { button: NowPlayingButton }) => {
  if (button.type !== 'image') {
    return undefined;
  }

  return NitroImageUtil.convert(button.image);
};

const convertNowPlayingButton = ({ button }: { button: NowPlayingButton }): NitroAction => ({
  title: button.type,
  image: getNowPlayingButtonImage({ button }),
  enabled: button.enabled,
  onPress: button.onPress,
  type: 'custom',
  flags: button.selected ? NOW_PLAYING_BUTTON_SELECTED_FLAG : undefined,
});

const convertNowPlayingButtons = ({ buttons }: { buttons?: Array<NowPlayingButton> }) =>
  buttons?.map((button) => convertNowPlayingButton({ button }));

export class NowPlayingTemplate {
  static configure({ config }: { config: NowPlayingTemplateConfig }) {
    const iosConfig = config.ios;

    if (!iosConfig) {
      return Promise.resolve();
    }

    return HybridAutoPlay.configureNowPlayingTemplate(
      iosConfig.upNextButton?.onPress ?? noop,
      iosConfig.albumArtistButton?.onPress ?? noop,
      iosConfig.upNextButton?.enabled,
      iosConfig.upNextButton?.title,
      iosConfig.albumArtistButton?.enabled,
      convertNowPlayingButtons({ buttons: iosConfig.buttons })
    );
  }

  static show({ animated, config }: NowPlayingTemplateShowOptions = {}) {
    const configurePromise = config ? NowPlayingTemplate.configure({ config }) : Promise.resolve();

    return configurePromise.then(() => HybridAutoPlay.showNowPlayingTemplate(animated));
  }
}
