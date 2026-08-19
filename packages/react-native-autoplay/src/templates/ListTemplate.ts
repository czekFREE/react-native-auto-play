import type { AutoImage } from '../types/Image';
import type { AutoText } from '../types/Text';
import { HybridListTemplate } from '../utils/HybridListTemplate';
import { NitroActionUtil } from '../utils/NitroAction';
import type { ThemedColor } from '../utils/NitroColor';
import type { NitroListTemplateConfig } from '../utils/NitroListTemplateConfig';
import { NitroMapButton } from '../utils/NitroMapButton';
import { NitroSectionUtil } from '../utils/NitroSection';
import {
  type ListTemplateDetailsHeader,
  ListTemplateDetailsHeaderUtil,
} from './ListTemplateDetailsHeader';
import type { BaseMapTemplateConfig } from './MapTemplate';
import { type HeaderActions, type NitroTemplateConfig, Template } from './Template';

export type PlayingIndicatorLocation = 'leading' | 'trailing';

export type { NitroListTemplateConfig } from '../utils/NitroListTemplateConfig';

type BaseRow = {
  title: AutoText;
  id?: string;
  enabled?: boolean;
  image?: AutoImage;
  isPlaying?: boolean;
  playbackDuration?: number;
  playbackElapsedTime?: number;
  playbackProgress?: number;
  playingIndicatorLocation?: PlayingIndicatorLocation;
};

export type DefaultRow<T> = BaseRow & {
  type: 'default';
  /**
   * Displays an SF Symbol in the trailing region of a CarPlay row.
   * @namespace ios
   */
  systemAccessoryImage?: string;
  /**
   * adds a chevron at the end of the row
   */
  browsable?: boolean;
  onPress: (template: T) => Promise<void> | void;
  detailedText?: AutoText;
};

export type ToggleRow<T> = BaseRow & {
  type: 'toggle';
  checked: boolean;
  onPress: (template: T, checked: boolean) => Promise<void> | void;
};

export type RadioRow<T> = BaseRow & {
  type: 'radio';
  onPress: (template: T) => Promise<void> | void;
  selected?: boolean;
};

export type TextRow = BaseRow & {
  type: 'text';
  detailedText?: AutoText;
};

type BaseImageRowItem<T> = {
  image: AutoImage;
  title?: AutoText;
  subtitle?: AutoText;
  /** Spoken label for image-only content on iOS 26.4 and newer. */
  accessibilityLabel?: string;
  enabled?: boolean;
  onPress?: (template: T) => Promise<void> | void;
};

export type ImageRowElement<T> = BaseImageRowItem<T>;

export type ImageRowCardElement<T> = BaseImageRowItem<T> & {
  showsImageFullHeight?: boolean;
  tintColor?: ThemedColor | string;
};

export type ImageRowCondensedElement<T> = BaseImageRowItem<T> & {
  title: AutoText;
  subtitle?: AutoText;
  imageShape: ImageRowElementShape;
  accessorySystemImage?: string;
};

export type ImageRowGridElement<T> = BaseImageRowItem<T>;

export type ImageRowImageGridElement<T> = BaseImageRowItem<T> & {
  title: AutoText;
  imageShape: ImageRowElementShape;
  accessorySystemImage?: string;
};

export type ImageRowElementShape = 'circular' | 'roundedRectangle';

type ImageRowBase<T> = BaseRow & {
  type: 'image';
  allowsMultipleLines?: boolean;
  onPress?: (template: T) => Promise<void> | void;
};

/**
 * Displays a horizontal collection of image elements on iOS. Android Auto
 * renders the parent row and ignores the nested image elements and variant.
 * @namespace iOS
 */
export type ImageRow<T> = ImageRowBase<T> &
  (
    | { variant?: 'row'; items: Array<ImageRowElement<T>> }
    | { variant: 'card'; items: Array<ImageRowCardElement<T>> }
    | { variant: 'condensed'; items: Array<ImageRowCondensedElement<T>> }
    | { variant: 'grid'; items: Array<ImageRowGridElement<T>> }
    | { variant: 'imageGrid'; items: Array<ImageRowImageGridElement<T>> }
  );

type RichSectionHeader = {
  /**
   * Displays supporting text in an enhanced CarPlay section header.
   * @namespace iOS
   */
  headerSubtitle?: string;
  /**
   * Displays artwork in an enhanced CarPlay section header.
   * Remote images are loaded asynchronously.
   * @namespace iOS
   */
  headerImage?: AutoImage;
};

export type MultiSection<T> =
  | (RichSectionHeader & {
      type: 'default';
      title: string;
      items: Array<DefaultRow<T> | ImageRow<T> | ToggleRow<T> | TextRow>;
    })
  | (RichSectionHeader & {
      type: 'radio';
      title: string;
      items: Array<RadioRow<T>>;
    });

export type SingleSection<T> = {
  [K in MultiSection<T> as K['type']]: Omit<
    K,
    'title' | 'headerImage' | 'headerSubtitle' | 'detailedText'
  >;
}[MultiSection<T>['type']];

export type Section<T> = Array<MultiSection<T>> | SingleSection<T>;

export type ListTemplateConfig = Omit<
  NitroListTemplateConfig,
  'detailsHeader' | 'headerActions' | 'sections' | 'mapConfig'
> & {
  /**
   * Rich media header displayed above list sections on iOS 26.4 and newer.
   * Ignored on unsupported platforms and OS versions.
   * @namespace iOS
   */
  detailsHeader?: ListTemplateDetailsHeader<ListTemplate>;
  /**
   * action buttons, usually at the the top right on Android and a top bar on iOS
   */
  headerActions?: HeaderActions<ListTemplate>;

  /**
   * a container that groups your list items into sections.
   * must have a single selected item in case it is a radio list.
   * in case it does not the first item will be selected.
   * in case it has multiple only the first selected one will be shown as selected.
   */
  sections?: Section<ListTemplate>;
  /**
   * If mapConfig is defined, it will use a MapWithContentTemplate with the current template. This results in a ListTemplate with a map in background. No actions need to be specified, can be empty object.
   * @namespace Android
   */
  mapConfig?: BaseMapTemplateConfig<ListTemplate>;
};

export class ListTemplate extends Template<ListTemplateConfig, HeaderActions<ListTemplate>> {
  private template = this;

  constructor(config: ListTemplateConfig) {
    super(config);

    const { detailsHeader, headerActions, mapConfig, sections, ...rest } = config;

    const nitroConfig: NitroListTemplateConfig & NitroTemplateConfig = {
      ...rest,
      detailsHeader: ListTemplateDetailsHeaderUtil.convert(this.template, detailsHeader),
      id: this.id,
      headerActions: NitroActionUtil.convert(this.template, headerActions),
      sections: NitroSectionUtil.convert(this.template, sections),
      mapConfig: mapConfig
        ? {
            mapButtons: NitroMapButton.convert(this.template, mapConfig.mapButtons),
            headerActions: NitroActionUtil.convert(this.template, mapConfig.headerActions),
          }
        : undefined,
    };

    HybridListTemplate.createListTemplate(nitroConfig);
  }

  public updateSections(sections?: Section<ListTemplate>) {
    return HybridListTemplate.updateListTemplateSections(
      this.id,
      NitroSectionUtil.convert(this.template, sections)
    );
  }

  public updateContent({
    detailsHeader,
    sections,
  }: {
    detailsHeader?: ListTemplateDetailsHeader<ListTemplate>;
    sections?: Section<ListTemplate>;
  }) {
    return HybridListTemplate.updateListTemplateContent(
      this.id,
      NitroSectionUtil.convert(this.template, sections),
      ListTemplateDetailsHeaderUtil.convert(this.template, detailsHeader)
    );
  }

  public updatePlayingItem(itemId?: string) {
    return HybridListTemplate.updateListTemplatePlayingItem(this.id, itemId);
  }
}
