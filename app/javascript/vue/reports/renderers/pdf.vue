<template>
  <div>
    <template v-if="pdf.error">
      <span class="flex items-center gap-1 text-sn-delete-red">
        <i class="fas fa-exclamation-triangle"></i>
        {{ i18n.t('projects.reports.index.error') }}
        <span v-if="pdf.preview_url" class="text-sn-black">|</span>
        <a v-if="pdf.preview_url" href="#"
           class="file-preview-link flex items-center gap-1
                  pdf hover:no-underline whitespace-nowrap"
           :data-preview-url="pdf.preview_url">
          {{ i18n.t('projects.reports.index.previous_pdf') }}
        </a>
      </span>
    </template>
    <template v-else-if="pdf.preview_url">
      <a v-if="pdf.preview_url" href="#"
          class="file-preview-link flex items-center gap-1
                pdf hover:no-underline whitespace-nowrap"
          :data-preview-url="pdf.preview_url">
        <i class="sn-icon sn-icon-file-word"></i>
        {{ i18n.t('projects.reports.index.pdf') }}
      </a>
    </template>
    <span v-else-if="pdf.processing" class="processing pdf">
      {{ i18n.t('projects.reports.index.generating') }}
    </span>
    <a v-else href="#" @click.prevent="generate">
      {{ i18n.t('projects.reports.index.generate') }}
    </a>
  </div>
</template>

<script>
import axios from '../../../packs/custom_axios.js';

export default {
  name: 'DocxRenderer',
  props: {
    params: {
      required: true
    }
  },
  data() {
    return {
      pdf: this.params.data.pdf_file
    };
  },
  mounted() {
    if (this.pdf.processing) {
      setTimeout(this.checkStatus, 3000);
    }
  },
  methods: {
    generate() {
      axios.post(this.params.data.urls.generate_pdf)
        .then(() => {
          this.pdf.processing = true;
          this.checkStatus();
        });
    },
    checkStatus() {
      axios.get(this.params.data.urls.status)
        .then((response) => {
          this.pdf = response.data.data.attributes.pdf_file;
          if (this.pdf.processing) {
            setTimeout(this.checkStatus, 3000);
          }
        });
    }
  }
};
</script>
