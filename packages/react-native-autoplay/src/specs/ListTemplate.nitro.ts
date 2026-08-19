import type { HybridObject } from 'react-native-nitro-modules';
import type { NitroListTemplateConfig } from '../utils/NitroListTemplateConfig';
import type { NitroListTemplateDetailsHeader } from '../utils/NitroListTemplateDetailsHeader';
import type { NitroTemplateConfig } from './AutoPlay.nitro';

interface ListTemplateConfig extends NitroTemplateConfig, NitroListTemplateConfig {}

export interface ListTemplate extends HybridObject<{ android: 'kotlin'; ios: 'swift' }> {
  createListTemplate(config: ListTemplateConfig): void;
  updateListTemplateSections(
    templateId: string,
    sections: NitroListTemplateConfig['sections']
  ): Promise<void>;
  updateListTemplateContent(
    templateId: string,
    sections: NitroListTemplateConfig['sections'],
    detailsHeader?: NitroListTemplateDetailsHeader
  ): Promise<void>;
  updateListTemplatePlayingItem(templateId: string, itemId?: string): Promise<void>;
  completeListItemPress(completionId: string): Promise<void>;
}
