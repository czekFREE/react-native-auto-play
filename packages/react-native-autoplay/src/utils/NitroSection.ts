import type {
  DefaultRow,
  PlayingIndicatorLocation,
  RadioRow,
  Section,
  TextRow,
  ToggleRow,
} from '../templates/ListTemplate';
import type { AutoText } from '../types/Text';
import { type NitroImage, NitroImageUtil } from './NitroImage';

type NitroSectionType = 'default' | 'radio';

export type NitroRow = {
  title: AutoText;
  id?: string;
  detailedText?: AutoText;
  browsable?: boolean;
  enabled: boolean;
  image?: NitroImage;
  isPlaying?: boolean;
  playbackDuration?: number;
  playbackElapsedTime?: number;
  playbackProgress?: number;
  playingIndicatorLocation?: PlayingIndicatorLocation;
  checked?: boolean;
  onPress?: (checked?: boolean, complete?: () => void) => void;
  selected?: boolean;
};

export type NitroSection = {
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
      const { title, type } = section;
      const items = section.items.map<NitroRow>((item) => convertRow(template, item));

      validateRadioItems(type, items);

      return {
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
  item: DefaultRow<T> | RadioRow<T> | ToggleRow<T> | TextRow
): NitroRow => {
  const { title, type, enabled = true, id, image } = item;

  const detailedText = 'detailedText' in item ? item.detailedText : undefined;
  const selected = type === 'radio' ? (item.selected ?? false) : undefined;

  const onTogglePress = item.type === 'toggle' ? item.onPress : undefined;
  const onRowPress = item.type !== 'text' && item.type !== 'toggle' ? item.onPress : undefined;

  const onPress: NitroRow['onPress'] =
    item.type === 'text'
      ? undefined
      : (checked?: boolean, complete?: () => void) => {
          const completePress = () => {
            complete?.();
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
    title,
    checked: type === 'toggle' ? item.checked : undefined,
    onPress,
    selected,
  };
};

export const NitroSectionUtil = { convert };
