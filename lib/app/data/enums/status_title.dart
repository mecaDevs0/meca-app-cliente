enum StatusTitle {
  agendamento('Agendamento'),
  orcamento('Orçamento'),
  pagamento('Pagamento'),
  servico('Serviço'),
  aprovacao('Aprovação'),
  concluido('Concluído');

  const StatusTitle(this.name);
  final String name;
}
