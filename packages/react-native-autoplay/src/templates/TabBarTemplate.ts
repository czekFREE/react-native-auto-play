import { Platform } from 'react-native';
import { NitroModules } from 'react-native-nitro-modules';
import type { TabBarTemplate as NitroTabBarTemplate } from '../specs/TabBarTemplate.nitro';
import type { ListTemplate } from './ListTemplate';
import { type NitroTemplateConfig, Template, type TemplateConfig } from './Template';

const HybridTabBarTemplate =
  Platform.OS === 'ios'
    ? NitroModules.createHybridObject<NitroTabBarTemplate>('TabBarTemplate')
    : null;

export interface NitroTabBarItem {
  templateId: string;
  title: string;
}

export interface NitroTabBarTemplateConfig extends TemplateConfig {
  tabs: NitroTabBarItem[];
  onTabSelected?: (templateId: string) => void;
}

export type TabBarTemplateConfig = Omit<NitroTabBarTemplateConfig, 'tabs'> & {
  tabs: Array<{
    template: ListTemplate;
    title: string;
  }>;
};

export class TabBarTemplate extends Template<TabBarTemplateConfig, never> {
  constructor(config: TabBarTemplateConfig) {
    super(config);

    if (HybridTabBarTemplate == null) {
      throw new Error(`TabBarTemplate is not supported on ${Platform.OS}`);
    }

    const { tabs, ...rest } = config;
    const nitroConfig: NitroTabBarTemplateConfig & NitroTemplateConfig = {
      ...rest,
      id: this.id,
      tabs: tabs.map(({ template, title }) => ({
        templateId: template.id,
        title,
      })),
    };

    HybridTabBarTemplate.createTabBarTemplate(nitroConfig);
  }

  public selectTab(template: ListTemplate) {
    if (HybridTabBarTemplate == null) {
      throw new Error(`TabBarTemplate is not supported on ${Platform.OS}`);
    }

    return HybridTabBarTemplate.selectTabBarTemplateTab(this.id, template.id);
  }
}
