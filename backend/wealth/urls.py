"""
URL configuration for wealth project.
"""
from django.contrib import admin
from django.urls import include, path
from rest_framework_simplejwt.views import TokenRefreshView

from accounts.views import LoginView

urlpatterns = [
    path('admin/', admin.site.urls),
    # JWT Auth - custom login supporting both legacy and KEK-based auth
    path('api/auth/login/', LoginView.as_view(), name='token_obtain_pair'),
    path('api/auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # App URLs
    path('api/', include('accounts.urls')),
    path('api/', include('brokers.urls')),
    path('api/', include('portfolio.urls')),
    path('api/', include('exchange_rates.urls')),
]
