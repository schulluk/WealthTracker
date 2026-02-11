from django.urls import path

from . import views

urlpatterns = [
    path('auth/register/', views.RegisterView.as_view(), name='register'),
    path('auth/me/', views.CurrentUserView.as_view(), name='current_user'),
    path('auth/change-password/', views.PasswordChangeView.as_view(), name='change_password'),
    path('auth/change-password/kek/', views.KEKPasswordChangeView.as_view(), name='change_password_kek'),
    path('auth/salt/', views.GetSaltView.as_view(), name='get_salt'),
    path('auth/salt/new/', views.GenerateNewSaltView.as_view(), name='generate_new_salt'),
    path('auth/setup-encryption/', views.SetupEncryptionView.as_view(), name='setup_encryption'),
    path('profile/', views.UserProfileView.as_view(), name='profile'),
    path('user/', views.UserUpdateView.as_view(), name='user_update'),
]
