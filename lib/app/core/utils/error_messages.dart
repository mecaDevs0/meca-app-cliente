class ErrorMessages {
  static String getNetworkError() {
    return 'Erro de conexão. Verifique sua internet e tente novamente.';
  }

  static String getServerError() {
    return 'Erro no servidor. Tente novamente em alguns instantes.';
  }

  static String getTimeoutError() {
    return 'Tempo limite excedido. Verifique sua conexão e tente novamente.';
  }

  static String getUnauthorizedError() {
    return 'Sessão expirada. Faça login novamente.';
  }

  static String getForbiddenError() {
    return 'Acesso negado. Verifique suas permissões.';
  }

  static String getNotFoundError() {
    return 'Recurso não encontrado.';
  }

  static String getValidationError(String field) {
    return 'Campo "$field" inválido. Verifique as informações.';
  }

  static String getLocationError() {
    return 'Erro ao obter localização. Verifique as permissões do app.';
  }

  static String getImageError() {
    return 'Erro ao processar imagem. Tente novamente.';
  }

  static String getPaymentError() {
    return 'Erro no pagamento. Verifique os dados e tente novamente.';
  }

  static String getGenericError() {
    return 'Ocorreu um erro inesperado. Tente novamente.';
  }

  static String getServiceUnavailableError() {
    return 'Serviço temporariamente indisponível. Tente novamente mais tarde.';
  }

  static String getDataLoadError() {
    return 'Erro ao carregar dados. Puxe para baixo para atualizar.';
  }

  static String getSaveError() {
    return 'Erro ao salvar dados. Verifique as informações e tente novamente.';
  }

  static String getDeleteError() {
    return 'Erro ao excluir. Tente novamente.';
  }

  static String getUploadError() {
    return 'Erro ao fazer upload. Verifique o arquivo e tente novamente.';
  }

  static String getNotificationError() {
    return 'Erro ao processar notificação.';
  }

  static String getAppointmentError() {
    return 'Erro ao agendar serviço. Verifique os dados e tente novamente.';
  }

  static String getVehicleError() {
    return 'Erro ao processar veículo. Verifique os dados e tente novamente.';
  }

  static String getProfileError() {
    return 'Erro ao atualizar perfil. Verifique os dados e tente novamente.';
  }
}
