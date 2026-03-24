// 配置 Flutter Web 使用 HTML 渲染器（避免 CanvasKit 加载失败）
_flutter.loader.loadEntrypoint({
  onEntrypointLoaded: async function(engineInitializer) {
    await engineInitializer.initializeEngine({
      renderer: 'html',
    });
    await _flutter.appRunner.runApp();
  }
});
