package com.margelo.nitro.swe.iternio.reactnativeautoplay

import com.margelo.nitro.core.Promise
import com.margelo.nitro.swe.iternio.reactnativeautoplay.template.AndroidAutoTemplate
import com.margelo.nitro.swe.iternio.reactnativeautoplay.template.ListTemplate

class HybridListTemplate : HybridListTemplateSpec() {

    override fun createListTemplate(config: ListTemplateConfig) {
        val context = AndroidAutoSession.getRootContext()
            ?: throw IllegalArgumentException("createListTemplate failed, carContext not found")

        val template = ListTemplate(context, config)
        AndroidAutoTemplate.setTemplate(config.id, template)
    }

    override fun updateListTemplateSections(
        templateId: String, sections: Array<NitroSection>?
    ): Promise<Unit> {
        return Promise.async {
            val template = AndroidAutoTemplate.getTemplate<ListTemplate>(templateId)
            template.updateSections(sections)
        }
    }

    override fun updateListTemplateContent(
        templateId: String,
        sections: Array<NitroSection>?,
        detailsHeader: NitroListTemplateDetailsHeader?
    ): Promise<Unit> {
        return Promise.async {
            val template = AndroidAutoTemplate.getTemplate<ListTemplate>(templateId)
            template.updateSections(sections)
        }
    }

    override fun updateListTemplatePlayingItem(
        templateId: String, itemId: String?
    ): Promise<Unit> {
        return Promise.async {
            Unit
        }
    }

    override fun completeListItemPress(completionId: String): Promise<Unit> {
        return Promise.resolved(Unit)
    }
}
