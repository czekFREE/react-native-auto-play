import type { NitroImage } from './NitroImage';

export type NitroListTemplateDetailsHeaderAction = {
  image: NitroImage;
  title?: string;
  enabled: boolean;
  onPress?: () => void;
};

export type NitroListTemplateDetailsHeader = {
  thumbnail: NitroImage;
  title?: string;
  subtitle?: string;
  bodyVariants: Array<string>;
  actionButtons: Array<NitroListTemplateDetailsHeaderAction>;
  adaptiveBackgroundStyle: boolean;
};
