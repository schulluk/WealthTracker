from django.urls import path

from . import views
from portfolio.views import BrokerDiscoverView, BrokerDiscoverCompleteAuthView

urlpatterns = [
    path('brokers/', views.BrokerListView.as_view(), name='broker_list'),
    path('brokers/discover/', BrokerDiscoverView.as_view(), name='broker_discover'),
    path('brokers/discover/complete-auth/', BrokerDiscoverCompleteAuthView.as_view(), name='broker_discover_complete_auth'),
    # EBICS subscriber credentials (shared across accounts, e.g. ZKB)
    path('ebics/credentials/', views.EbicsCredentialListCreateView.as_view(), name='ebics_credential_list'),
    path('ebics/credentials/<int:pk>/', views.EbicsCredentialDetailView.as_view(), name='ebics_credential_detail'),
    path('ebics/credentials/<int:pk>/initialize/', views.EbicsCredentialInitializeView.as_view(), name='ebics_credential_initialize'),
    path('ebics/credentials/<int:pk>/letter/', views.EbicsCredentialLetterView.as_view(), name='ebics_credential_letter'),
    path('ebics/credentials/<int:pk>/test/', views.EbicsCredentialTestView.as_view(), name='ebics_credential_test'),
    path('brokers/<str:code>/', views.BrokerDetailView.as_view(), name='broker_detail'),
]
