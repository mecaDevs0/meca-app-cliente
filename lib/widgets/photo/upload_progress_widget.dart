import 'package:flutter/material.dart';
import '../../services/photo/upload_service.dart';

/// Estado do upload de uma imagem
enum UploadState {
  pending,
  uploading,
  success,
  error,
}

/// Widget para exibir progresso de upload de uma imagem
class UploadProgressWidget extends StatelessWidget {
  final UploadState state;
  final UploadProgress? progress;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const UploadProgressWidget({
    Key? key,
    required this.state,
    this.progress,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusText(),
                if (state == UploadState.uploading && progress != null) ...[
                  const SizedBox(height: 4),
                  _buildProgressBar(),
                ],
                if (state == UploadState.error && errorMessage != null) ...[
                  const SizedBox(height: 4),
                  _buildErrorMessage(),
                ],
              ],
            ),
          ),
          if (state == UploadState.uploading && onCancel != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.cancel, size: 20),
              onPressed: onCancel,
              color: Colors.grey,
            ),
          ],
          if (state == UploadState.error && onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (state) {
      case UploadState.pending:
        return const Icon(Icons.pending, color: Colors.grey, size: 20);
      case UploadState.uploading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C977)),
          ),
        );
      case UploadState.success:
        return const Icon(Icons.check_circle, color: Color(0xFF00C977), size: 20);
      case UploadState.error:
        return const Icon(Icons.error, color: Colors.red, size: 20);
    }
  }

  Widget _buildStatusText() {
    String text;
    switch (state) {
      case UploadState.pending:
        text = 'Aguardando upload...';
        break;
      case UploadState.uploading:
        if (progress != null) {
          text = 'Enviando... ${progress!.percentage.toStringAsFixed(0)}%';
        } else {
          text = 'Enviando...';
        }
        break;
      case UploadState.success:
        text = 'Upload concluído';
        break;
      case UploadState.error:
        text = 'Erro no upload';
        break;
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildProgressBar() {
    if (progress == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress!.percentage / 100,
        backgroundColor: Colors.grey.shade200,
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C977)),
        minHeight: 4,
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();

    return Text(
      errorMessage!,
      style: TextStyle(
        fontSize: 12,
        color: Colors.red.shade700,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _getBackgroundColor() {
    switch (state) {
      case UploadState.pending:
        return Colors.grey.shade50;
      case UploadState.uploading:
        return const Color(0xFF00C977).withOpacity(0.05);
      case UploadState.success:
        return const Color(0xFF00C977).withOpacity(0.1);
      case UploadState.error:
        return Colors.red.shade50;
    }
  }

  Color _getBorderColor() {
    switch (state) {
      case UploadState.pending:
        return Colors.grey.shade300;
      case UploadState.uploading:
        return const Color(0xFF00C977).withOpacity(0.3);
      case UploadState.success:
        return const Color(0xFF00C977);
      case UploadState.error:
        return Colors.red.shade300;
    }
  }
}

/// Widget para exibir lista de progressos de upload
class UploadProgressListWidget extends StatelessWidget {
  final List<UploadProgressItem> items;

  const UploadProgressListWidget({
    Key? key,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status do upload:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: UploadProgressWidget(
                state: item.state,
                progress: item.progress,
                errorMessage: item.errorMessage,
                onRetry: item.onRetry,
                onCancel: item.onCancel,
              ),
            )),
      ],
    );
  }
}

/// Item de progresso de upload
class UploadProgressItem {
  final UploadState state;
  final UploadProgress? progress;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  UploadProgressItem({
    required this.state,
    this.progress,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
  });
}




