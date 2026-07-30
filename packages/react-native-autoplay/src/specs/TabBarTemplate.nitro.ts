import type { HybridObject } from 'react-native-nitro-modules';
import type { NitroTabBarTemplateConfig } from '../templates/TabBarTemplate';
import type { NitroTemplateConfig } from './AutoPlay.nitro';

interface TabBarTemplateConfig extends NitroTemplateConfig, NitroTabBarTemplateConfig {}

export interface TabBarTemplate extends HybridObject<{ ios: 'swift' }> {
  createTabBarTemplate(config: TabBarTemplateConfig): void;
  selectTabBarTemplateTab(tabBarTemplateId: string, selectedTemplateId: string): Promise<void>;
}
