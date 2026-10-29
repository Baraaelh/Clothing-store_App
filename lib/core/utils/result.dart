import '../error/failures.dart';

/// نتيجة عملية: نجاح [Ok] بقيمة، أو فشل [Err] بـ [Failure].
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onOk) {
    final self = this;
    return switch (self) {
      Ok<T>() => onOk(self.value),
      Err<T>() => onFailure(self.failure),
    };
  }
}

class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
