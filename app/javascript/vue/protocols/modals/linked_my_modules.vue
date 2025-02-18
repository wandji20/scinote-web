<template>
  <div ref="modal" class="modal" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document">
      <div class="modal-content ">
        <div class="modal-header">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close">
            <i class="sn-icon sn-icon-close"></i>
          </button>
          <h4 class="modal-title truncate !block">
            {{ i18n.t('protocols.index.linked_children.title', { protocol: protocol.name }) }}
          </h4>
        </div>
        <div class="modal-body">
          <div class="max-h-96 overflow-y-auto">
            <div v-for="myModule in linkedMyModules" class="flex items-center gap-2 px-3 py-2">
              <a :href="myModule.project_url"
                 :title="myModule.project_name"
                 class="hover:no-underline flex items-center gap-1 shrink-0">
                <i class="sn-icon sn-icon-projects"></i>
                <span class="truncate max-w-[130px]">{{ myModule.project_name }}</span>
              </a>
              <span>/</span>
              <a :href="myModule.experiment_url"
                 :title="myModule.experiment_name"
                 class="hover:no-underline flex items-center gap-1 shrink-0">
                <i class="sn-icon sn-icon-experiment"></i>
                <span class="truncate max-w-[130px]">{{ myModule.experiment_name }}</span>
              </a>
              <span>/</span>
              <a :href="myModule.my_module_url"
                 :title="myModule.my_module_name"
                 class="hover:no-underline flex items-center gap-1 shrink-0">
                <i class="sn-icon sn-icon-task"></i>
                <span class="truncate max-w-[130px]">{{ myModule.my_module_name }}</span>
              </a>
            </div>
          </div>
          <div class="flex mt-4">
            <Pagination
              v-if="totalPage"
              :totalPage="totalPage"
              :currentPage="page"
              @setPage="setPage"
            ></Pagination>
          </div>
        </div>
        <div class="modal-footer items-center">
          {{ i18n.t("protocols.index.linked_children.show_version") }}
          <div class="w-48 mr-auto">
            <SelectDropdown
              :options="versionsList"
              :value="selectedVersion"
              @change="changeSelectedVersion"
            ></SelectDropdown>
          </div>
          <button type="button" class="btn btn-secondary" data-dismiss="modal">{{ i18n.t('general.cancel') }}</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>

import SelectDropdown from '../../shared/select_dropdown.vue';
import axios from '../../../packs/custom_axios.js';
import modalMixin from '../../shared/modal_mixin';
import Pagination from '../../shared/datatable/pagination.vue';

export default {
  name: 'NewProtocolModal',
  props: {
    protocol: Object
  },
  mixins: [modalMixin],
  components: {
    SelectDropdown,
    Pagination
  },
  data() {
    return {
      linkedMyModules: [],
      versionsList: [],
      selectedVersion: 'All',
      page: 1,
      totalPage: null
    };
  },
  mounted() {
    this.loadLinkedMyModules();
    this.loadVersions();
  },
  methods: {
    loadLinkedMyModules() {
      const urlParams = { page: this.page };
      if (this.selectedVersion !== 'All') {
        urlParams.version = this.selectedVersion;
      }
      axios.get(this.protocol.urls.linked_my_modules, { params: urlParams })
        .then((response) => {
          this.linkedMyModules = response.data.data;
          this.totalPage = response.data.total_pages;
        });
    },
    loadVersions() {
      axios.get(this.protocol.urls.versions_list)
        .then((response) => {
          this.versionsList = [['All', 'All']].concat(response.data.versions.map((version) => [version, version]));
        });
    },
    changeSelectedVersion(version) {
      this.selectedVersion = version;
      this.page = 1;
      this.loadLinkedMyModules();
    },
    setPage(page) {
      this.page = page;
      this.loadLinkedMyModules();
    }
  }
};
</script>
