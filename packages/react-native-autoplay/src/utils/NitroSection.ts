import type {
  DefaultRow,
  ImageRow,
  PlayingIndicatorLocation,
  RadioRow,
  Section,
  TextRow,
  ToggleRow,
} from '../templates/ListTemplate';
import type { AutoText } from '../types/Text';
import { HybridListTemplate } from './HybridListTemplate';
import { type NitroColor, NitroColorUtil } from './NitroColor';
import { type NitroImage, NitroImageUtil } from './NitroImage';

type NitroSectionType = 'default' | 'radio';

export type NitroRow = {
  title: AutoText;
  id?: string;
  detailedText?: AutoText;
  systemAccessoryImage?: string;
  browsable?: boolean;
  enabled: boolean;
  image?: NitroImage;
  isPlaying?: boolean;
  playbackDuration?: number;
  playbackElapsedTime?: number;
  playbackProgress?: number;
  playingIndicatorLocation?: PlayingIndicatorLocation;
  checked?: boolean;
  onPress?: (checked?: boolean, completionId?: string) => void;
  selected?: boolean;
  imageRowItems?: Array<NitroImageRowItem>;
  imageRowVariant?: NitroImageRowVariant;
  imageRowAllowsMultipleLines?: boolean;
};

export type NitroImageRowItem = {
  title?: string;
  subtitle?: string;
  image: NitroImage;
  enabled: boolean;
  showsImageFullHeight?: boolean;
  tintColor?: NitroColor;
  imageShape?: NitroImageRowElementShape;
  accessorySystemImage?: string;
  accessibilityLabel?: string;
  onPress?: (completionId?: string) => void;
};

export type NitroImageRowVariant = 'row' | 'card' | 'condensed' | 'grid' | 'imageGrid';
export type NitroImageRowElementShape = 'circular' | 'roundedRectangle';

export type NitroSection = {
  headerImage?: NitroImage;
  headerSubtitle?: string;
  title?: string;
  items: Array<NitroRow>;
  type: NitroSectionType;
};

const validateRadioItems = (type: NitroSectionType, items: Array<NitroRow>) => {
  if (
    __DEV__ &&
    type === 'radio' &&
    (items.filter((item) => item.selected).length > 1 || items.every((item) => !item.selected))
  ) {
    throw new Error('radio lists must have one selected item');
  }
};

const convert = <T>(template: T, sections?: Section<T>): Array<NitroSection> | undefined => {
  if (sections == null) {
    return undefined;
  }

  if (Array.isArray(sections)) {
    return sections.map<NitroSection>((section) => {
      const { headerImage, headerSubtitle, title, type } = section;
      const items = section.items.map<NitroRow>((item) => convertRow(template, item));

      validateRadioItems(type, items);

      return {
        headerImage: NitroImageUtil.convert(headerImage),
        headerSubtitle,
        items,
        type,
        title,
      };
    });
  }

  const items = sections.items.map((item) => convertRow(template, item));

  validateRadioItems(sections.type, items);

  return [
    {
      items,
      type: sections.type,
    },
  ];
};

const convertRow = <T>(
  template: T,
  item: DefaultRow<T> | ImageRow<T> | RadioRow<T> | ToggleRow<T> | TextRow
): NitroRow => {
  const { title, type, enabled = true, id } = item;

  const image = 'image' in item ? item.image : undefined;
  const detailedText = 'detailedText' in item ? item.detailedText : undefined;
  const systemAccessoryImage =
    'systemAccessoryImage' in item ? item.systemAccessoryImage : undefined;
  const selected = type === 'radio' ? (item.selected ?? false) : undefined;

  const onTogglePress = item.type === 'toggle' ? item.onPress : undefined;
  const onRowPress = item.type !== 'text' && item.type !== 'toggle' ? item.onPress : undefined;

  const onPress: NitroRow['onPress'] =
    item.type === 'text'
      ? undefined
      : (checked?: boolean, completionId?: string) => {
          const completePress = () => {
            if (completionId != null) {
              void HybridListTemplate.completeListItemPress(completionId);
            }
          };

          if (onTogglePress != null && checked != null) {
            void Promise.resolve(onTogglePress(template, checked)).then(
              completePress,
              completePress
            );
            return;
          }
          if (onRowPress != null) {
            void Promise.resolve(onRowPress(template)).then(completePress, completePress);
            return;
          }

          completePress();
        };

  const imageRowItems =
    item.type === 'image'
      ? item.items.map<NitroImageRowItem>((imageRowItem) => ({
          accessibilityLabel:
            'accessibilityLabel' in imageRowItem ? imageRowItem.accessibilityLabel : undefined,
          accessorySystemImage:
            'accessorySystemImage' in imageRowItem ? imageRowItem.accessorySystemImage : undefined,
          enabled: imageRowItem.enabled ?? true,
          image: NitroImageUtil.convert(imageRowItem.image),
          imageShape: 'imageShape' in imageRowItem ? imageRowItem.imageShape : undefined,
          onPress: imageRowItem.onPress
            ? (completionId?: string) => {
                const completePress = () => {
                  if (completionId != null) {
                    void HybridListTemplate.completeListItemPress(completionId);
                  }
                };

                void Promise.resolve(imageRowItem.onPress?.(template)).then(
                  completePress,
                  completePress
                );
              }
            : undefined,
          showsImageFullHeight:
            'showsImageFullHeight' in imageRowItem ? imageRowItem.showsImageFullHeight : undefined,
          subtitle: 'subtitle' in imageRowItem ? imageRowItem.subtitle?.text : undefined,
          tintColor:
            'tintColor' in imageRowItem
              ? NitroColorUtil.convert(imageRowItem.tintColor)
              : undefined,
          title: 'title' in imageRowItem ? imageRowItem.title?.text : undefined,
        }))
      : undefined;

  return {
    browsable: type === 'default' ? item.browsable : undefined,
    detailedText,
    enabled,
    id,
    image: NitroImageUtil.convert(image),
    isPlaying: item.isPlaying,
    playbackDuration: item.playbackDuration,
    playbackElapsedTime: item.playbackElapsedTime,
    playbackProgress: item.playbackProgress,
    playingIndicatorLocation: item.playingIndicatorLocation,
    systemAccessoryImage,
    title,
    checked: type === 'toggle' ? item.checked : undefined,
    onPress,
    selected,
    imageRowItems,
    imageRowAllowsMultipleLines:
      item.type === 'image' ? (item.allowsMultipleLines ?? false) : undefined,
    imageRowVariant: item.type === 'image' ? (item.variant ?? 'row') : undefined,
  };
};

export const NitroSectionUtil = { convert };
