import type { AutoImage } from '../types/Image';
import type { AutoText } from '../types/Text';
import { NitroImageUtil } from '../utils/NitroImage';
import type { NitroListTemplateDetailsHeader } from '../utils/NitroListTemplateDetailsHeader';

export type ListTemplateDetailsHeaderAction<T> = {
  image: AutoImage;
  title?: string;
  enabled?: boolean;
  onPress?: (template: T) => Promise<void> | void;
};

export type ListTemplateDetailsHeader<T> = {
  thumbnail: AutoImage;
  title?: AutoText;
  subtitle?: AutoText;
  bodyVariants?: Array<AutoText>;
  actionButtons?: Array<ListTemplateDetailsHeaderAction<T>>;
  adaptiveBackgroundStyle?: boolean;
};

const convert = <T>(
  template: T,
  detailsHeader?: ListTemplateDetailsHeader<T>
): NitroListTemplateDetailsHeader | undefined => {
  if (detailsHeader == null) {
    return undefined;
  }

  return {
    actionButtons: (detailsHeader.actionButtons ?? []).map((actionButton) => ({
      enabled: actionButton.enabled ?? true,
      image: NitroImageUtil.convert(actionButton.image),
      onPress: actionButton.onPress
        ? () => {
            void actionButton.onPress?.(template);
          }
        : undefined,
      title: actionButton.title,
    })),
    adaptiveBackgroundStyle: detailsHeader.adaptiveBackgroundStyle ?? false,
    bodyVariants: (detailsHeader.bodyVariants ?? []).map(({ text }) => text),
    subtitle: detailsHeader.subtitle?.text,
    thumbnail: NitroImageUtil.convert(detailsHeader.thumbnail),
    title: detailsHeader.title?.text,
  };
};

export const ListTemplateDetailsHeaderUtil = { convert };
