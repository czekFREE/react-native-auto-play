import type { NitroBaseMapTemplateConfig, TemplateConfig } from '../templates/Template';
import type { AutoText } from '../types/Text';
import type { NitroAction } from './NitroAction';
import type { NitroListTemplateDetailsHeader } from './NitroListTemplateDetailsHeader';
import type { NitroSection } from './NitroSection';

export interface NitroListTemplateConfig extends TemplateConfig {
  detailsHeader?: NitroListTemplateDetailsHeader;
  headerActions?: Array<NitroAction>;
  title: AutoText;
  sections?: Array<NitroSection>;
  mapConfig?: NitroBaseMapTemplateConfig;
}
