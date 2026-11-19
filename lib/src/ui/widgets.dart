import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../demo/demo_backend.dart';
import 'error_message.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, this.onRetry});

  final ApiException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('error-banner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                describeError(error),
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            if (onRetry != null && canRetry(error))
              TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Lets you pick how the demo backend answers the next request.
class ScenarioPicker extends StatelessWidget {
  const ScenarioPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = context.watch<DemoSettings>();
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Simulate server response',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DemoScenario>(
          key: const Key('scenario'),
          value: demo.scenario,
          isExpanded: true,
          isDense: true,
          items: [
            for (final scenario in DemoScenario.values)
              DropdownMenuItem(value: scenario, child: Text(scenario.label)),
          ],
          onChanged: (value) {
            if (value != null) demo.scenario = value;
          },
        ),
      ),
    );
  }
}
